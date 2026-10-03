//
//  CourseReminderService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import UserNotifications
#if os(iOS)
import BackgroundTasks
import SwiftData
#endif

@MainActor
public final class CourseReminderService {
    public static let shared = CourseReminderService()

    private struct ReminderCandidate {
        let identifier: String
        let title: String
        let body: String
        let category: String
        let fireDate: Date
    }

    private init() {}

    /// 按课程的实际教学周生成一次性提醒，并保留每日通知的名额。
    /// iOS 每个 App 最多保留 64 个待处理本地通知；回到前台时重新排程后续场次。
    public func syncAllCourseReminders(courses: [CourseItem], completion: (() -> Void)? = nil) {
        NotificationManager.shared.reschedule(courses: courses, completion: completion)
    }

    /// Build requests only; NotificationManager owns all queue mutations and capacity.
    func requests(courses: [CourseItem], now: Date, settings: AppSettings) -> [UNNotificationRequest] {
        let candidates = courses.filter(\.isEnabled).flatMap {
            reminderCandidates(for: $0, allCourses: courses, now: now,
                semesterStartDate: settings.semesterStartDate,
                needsPreClass: settings.classReminderEnabled, needsPostClass: settings.postClassReminderEnabled)
        }.sorted { $0.fireDate < $1.fireDate }
        return candidates.map { candidate in
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            content.categoryIdentifier = candidate.category
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.fireDate)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            return UNNotificationRequest(identifier: candidate.identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        }
    }

    /// 取消单个课程提醒（包括课前预警与下课关怀）。
    public func cancelCourseReminder(course: CourseItem) {
        let id = course.id.uuidString
        removeCourseRequests {
            $0 == "qianyu_course_\(id)" || $0 == "qianyu_course_post_\(id)" ||
            (($0.hasPrefix("qianyu_course_pre_") || $0.hasPrefix("qianyu_course_post_")) && $0.contains("_\(id)_"))
        }
    }

    /// 清空所有课前与课后系统通知。
    public func removeAllCourseReminders() {
        removeCourseRequests { $0.hasPrefix("qianyu_course_") }
    }

    public func removeAllPostClassReminders() {
        removeCourseRequests { $0.hasPrefix("qianyu_course_post_") }
    }

    private func removeCourseRequests(where shouldRemove: @escaping (String) -> Bool) {
        NotificationManager.shared.removePendingRequests(where: shouldRemove)
    }

    private func reminderCandidates(
        for course: CourseItem,
        allCourses: [CourseItem],
        now: Date,
        semesterStartDate: Date,
        needsPreClass: Bool,
        needsPostClass: Bool
    ) -> [ReminderCandidate] {
        guard needsPreClass || needsPostClass else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        let weeks = course.effectiveWeeks.sorted()

        guard (1...7).contains(course.weekday) else { return [] }
        var result: [ReminderCandidate] = []

        for week in weeks {
            guard let classDate = CourseTimeRules.classDay(week: week, weekday: course.weekday,
                                                           semesterStart: semesterStartDate, calendar: calendar),
                  let classStart = CourseTimeRules.time(course.startTotalMinutes, on: classDate, calendar: calendar),
                  let classEnd = CourseTimeRules.time(course.endTotalMinutes, on: classDate, calendar: calendar) else { continue }

            let weekSuffix = "\(course.id.uuidString)_\(week)"
            if needsPreClass,
               let fireDate = calendar.date(byAdding: .minute, value: -course.remindBeforeMinutes, to: classStart),
               fireDate > now {
                result.append(
                    ReminderCandidate(
                        identifier: "qianyu_course_pre_\(weekSuffix)",
                        title: EditorialCopy.text("notification.course.pre.title", ["courseName": course.name]),
                        body: course.qianyuReminderMessage,
                        category: "QIANYU_COURSE_REMINDER",
                        fireDate: fireDate
                    )
                )
            }

            if needsPostClass, classEnd > now {
                let nextCourse = allCourses
                    .filter { $0.isEnabled && $0.weekday == course.weekday && $0.id != course.id
                        && $0.isActive(inWeek: week) && $0.startTotalMinutes >= course.endTotalMinutes }
                    .min { $0.startTotalMinutes < $1.startTotalMinutes }
                result.append(
                    ReminderCandidate(
                        identifier: "qianyu_course_post_\(weekSuffix)",
                        title: EditorialCopy.text("notification.course.post.title", ["courseName": course.name]),
                        body: course.postClassReminderMessage(nextCourse: nextCourse),
                        category: "QIANYU_COURSE_POST_REMINDER",
                        fireDate: classEnd
                    )
                )
            }
        }
        return result
    }
}

#if os(iOS)
/// 在系统允许后台刷新时补排后续课程。iOS 决定实际执行时间，前台激活仍会立即补排。
public enum CourseReminderBackgroundRefresh {
    private static let identifier = "com.qianyu.companion.course-reminder-refresh"

    @MainActor
    public static func refresh(container: ModelContainer) async {
        do {
            let courses = try container.mainContext.fetch(FetchDescriptor<CourseItem>())
            await withCheckedContinuation { continuation in
                CourseReminderService.shared.syncAllCourseReminders(courses: courses) {
                    continuation.resume()
                }
            }
            await NotificationManager.shared.waitForDailyContentRefresh()
        } catch {
            NSLog("后台补排课程提醒失败：%@", error.localizedDescription)
        }
    }

    public static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NSLog("提交课程提醒后台补排任务失败：%@", error.localizedDescription)
        }
    }
}
#endif
