//
//  CalendarSyncService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import EventKit
import SwiftUI

@MainActor
public final class CalendarSyncService {
    public static let shared = CalendarSyncService()
    private let eventStore = EKEventStore()
    private let calendarTitle = "QIAN YU 课表"
    private let eventMarker = "QIAN_YU_COURSE_ID:"
    private let legacyEventMarker = "由「QIAN YU (千语伴行)」同步"
    private let lastSyncedSemesterKey = "qianyu.calendar.lastSyncedSemesterMonday"

    private init() {}

    /// 请求日历访问权限
    public func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// 获取或创建专属的「QIAN YU 课表」日历
    private func getOrCreateQianyuCalendar() throws -> EKCalendar {
        // 查找已有日历
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // 创建新日历
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarTitle
        newCalendar.cgColor = CGColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0) // 暖橙色

        // 寻找合适的 source (iCloud 或 本地 Default)
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let firstSource = eventStore.sources.first {
            newCalendar.source = firstSource
        }

        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }

    /// 将课程一键批量同步至系统日历
    /// - Parameters:
    ///   - courses: 需要同步的课程数组
    ///   - semesterStartDate: 开学第一周起始日期
    /// - Returns: 成功导出的课程节数
    public func syncCoursesToSystemCalendar(
        courses: [CourseItem],
        semesterStartDate: Date
    ) async throws -> Int {
        let granted = await requestCalendarAccess()
        guard granted else {
            throw CalendarSyncError.permissionDenied
        }

        let calendar = try getOrCreateQianyuCalendar()
        var committed = false
        defer {
            if !committed { eventStore.reset() }
        }

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        guard let semesterMonday = cal.dateInterval(of: .weekOfYear, for: semesterStartDate)?.start else {
            throw CalendarSyncError.failedToSave
        }

        // 日期可能已从旧学期切换到新学期。按年度分段检查相邻学期，
        // 同时覆盖升级前未记录同步日期的课程事件。
        let previousSyncTimestamp = UserDefaults.standard.double(forKey: lastSyncedSemesterKey)
        let previousSyncDate = previousSyncTimestamp > 0
            ? Date(timeIntervalSince1970: previousSyncTimestamp)
            : semesterMonday
        let scanOrigin = min(semesterMonday, Date(), previousSyncDate)
        let scanEnd = max(semesterMonday, Date())
        guard let firstYear = cal.date(byAdding: .year, value: -2, to: scanOrigin),
              let lastYear = cal.date(byAdding: .year, value: 2, to: scanEnd) else {
            throw CalendarSyncError.failedToSave
        }
        var cursor = firstYear
        while cursor < lastYear {
            guard let next = cal.date(byAdding: .year, value: 1, to: cursor) else { break }
            let predicate = eventStore.predicateForEvents(withStart: cursor, end: min(next, lastYear), calendars: [calendar])
            for oldEvent in eventStore.events(matching: predicate) where isOwnedEvent(oldEvent) {
                try eventStore.remove(oldEvent, span: .thisEvent, commit: false)
            }
            cursor = next
        }

        var syncedCount = 0
        // 2. 每个实际生效的教学周创建一条独立事件，避免 recurrence 无法表达稀疏周次。
        for course in courses where course.isEnabled {
            guard (1...7).contains(course.weekday) else { continue }
            let activeWeeks = resolvedActiveWeeks(for: course)
            var savedCourseEvents = false

            for week in activeWeeks {
                let (weekOffset, overflow) = (week - 1).multipliedReportingOverflow(by: 7)
                let (dayOffset, additionOverflow) = weekOffset.addingReportingOverflow(course.weekday - 1)
                guard !overflow, !additionOverflow,
                      let classDate = cal.date(
                        byAdding: .day,
                        value: dayOffset,
                        to: semesterMonday
                      ) else {
                    continue
                }

                var startComp = cal.dateComponents([.year, .month, .day], from: classDate)
                startComp.hour = course.startHour
                startComp.minute = course.startMinute
                guard let eventStart = cal.date(from: startComp) else { continue }

                var endComp = cal.dateComponents([.year, .month, .day], from: classDate)
                endComp.hour = course.endHour
                endComp.minute = course.endMinute
                guard let eventEnd = cal.date(from: endComp) else { continue }

                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                event.title = course.name
                event.location = course.classroom.isEmpty ? String(localized: "教室") : course.classroom
                let teacher = course.teacher.isEmpty ? String(localized: "未指定") : course.teacher
                let noteSummary = String(localized: "授课教师: \(teacher)\n教学周: 第\(week)周")
                event.notes = "\(noteSummary)\n\(eventMarker)\(course.id.uuidString):\(week)\n—— \(legacyEventMarker)"
                event.startDate = eventStart
                event.endDate = eventEnd

                if course.remindBeforeMinutes > 0 {
                    let alarm = EKAlarm(relativeOffset: -Double(course.remindBeforeMinutes * 60))
                    event.addAlarm(alarm)
                }

                try eventStore.save(event, span: .thisEvent, commit: false)
                savedCourseEvents = true
            }

            if savedCourseEvents { syncedCount += 1 }
        }

        try eventStore.commit()
        committed = true
        UserDefaults.standard.set(semesterMonday.timeIntervalSince1970, forKey: lastSyncedSemesterKey)
        return syncedCount
    }

    private func isOwnedEvent(_ event: EKEvent) -> Bool {
        guard let notes = event.notes else { return false }
        return notes.contains(eventMarker) || notes.contains(legacyEventMarker)
    }

    private func resolvedActiveWeeks(for course: CourseItem) -> [Int] {
        if !course.activeWeeks.isEmpty {
            return course.activeWeeks.filter { $0 > 0 }.sorted()
        }
        guard course.startWeek > 0,
              course.endWeek >= course.startWeek,
              course.endWeek - course.startWeek <= 100 else {
            return []
        }
        return (course.startWeek...course.endWeek).filter { course.isActive(inWeek: $0) }
    }
}

public enum CalendarSyncError: LocalizedError {
    case permissionDenied
    case failedToSave

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "未能获取日历访问权限。请前往系统「设置」->「隐私与安全性」->「日历」中允许 QIAN YU 访问。")
        case .failedToSave:
            return String(localized: "保存日历事件失败，请稍后重试。")
        }
    }
}
