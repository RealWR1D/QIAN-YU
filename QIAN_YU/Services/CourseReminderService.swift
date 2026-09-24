//
//  CourseReminderService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import UserNotifications

public final class CourseReminderService {
    public static let shared = CourseReminderService()

    private init() {}

    /// 同步所有启用的课程提醒到系统通知中心
    public func syncAllCourseReminders(courses: [CourseItem]) {
        let center = UNUserNotificationCenter.current()

        // 首先获取所有现存的课程提醒 ID
        center.getPendingNotificationRequests { requests in
            let courseIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("qianyu_course_") }
            center.removePendingNotificationRequests(withIdentifiers: courseIds)

            guard AppSettings.shared.classReminderEnabled else { return }

            // 重新安排所有启用的课程
            for course in courses where course.isEnabled {
                self.scheduleCourseReminder(course: course)
            }
        }
    }

    /// 安排单个课程的周期性通知
    public func scheduleCourseReminder(course: CourseItem) {
        guard course.isEnabled, AppSettings.shared.classReminderEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "qianyu_course_\(course.id.uuidString)"

        let content = UNMutableNotificationContent()
        content.title = "上课提醒 · \(course.name)"
        content.body = course.qianyuReminderMessage
        content.sound = .default
        content.categoryIdentifier = "QIANYU_COURSE_REMINDER"

        // 计算提前提醒后的具体小时与分钟
        let totalStartMinutes = course.startTotalMinutes
        var remindTotalMinutes = totalStartMinutes - course.remindBeforeMinutes
        var targetWeekday = course.weekday
        if remindTotalMinutes < 0 {
            remindTotalMinutes += 24 * 60
            targetWeekday = (targetWeekday == 1) ? 7 : targetWeekday - 1
        }

        let remindHour = remindTotalMinutes / 60
        let remindMinute = remindTotalMinutes % 60

        // 转换 weekday 为 Apple 系统规范 (1=周日, 2=周一 ... 7=周六)
        let appleWeekday = (targetWeekday % 7) + 1

        var components = DateComponents()
        components.weekday = appleWeekday
        components.hour = remindHour
        components.minute = remindMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("安排课程提醒 \(course.name) 失败: \(error)")
            }
        }

        // 下课收尾贴心关怀通知
        if AppSettings.shared.postClassReminderEnabled {
            schedulePostClassReminder(course: course)
        }
    }

    /// 安排下课收尾时的千语舒缓贴心问候
    public func schedulePostClassReminder(course: CourseItem) {
        let center = UNUserNotificationCenter.current()
        let identifier = "qianyu_course_post_\(course.id.uuidString)"

        let content = UNMutableNotificationContent()
        content.title = "下课啦 · \(course.name)"
        content.body = course.postClassReminderMessage()
        content.sound = .default
        content.categoryIdentifier = "QIANYU_COURSE_POST_REMINDER"

        let appleWeekday = (course.weekday % 7) + 1
        var components = DateComponents()
        components.weekday = appleWeekday
        components.hour = course.endHour
        components.minute = course.endMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("安排下课关怀提醒 \(course.name) 失败: \(error)")
            }
        }
    }

    /// 取消单个课程提醒 (包括课前预警与下课关怀)
    public func cancelCourseReminder(course: CourseItem) {
        let preId = "qianyu_course_\(course.id.uuidString)"
        let postId = "qianyu_course_post_\(course.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [preId, postId])
    }

    /// 清空所有课前与课后系统通知
    public func removeAllCourseReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let courseIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("qianyu_course_") }
            center.removePendingNotificationRequests(withIdentifiers: courseIds)
        }
    }

    /// 清空所有课后关怀系统通知
    public func removeAllPostClassReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let postIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("qianyu_course_post_") }
            center.removePendingNotificationRequests(withIdentifiers: postIds)
        }
    }
}
