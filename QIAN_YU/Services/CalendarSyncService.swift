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

        // 1. 清理已有该日历中旧的由 QIAN YU 创建的未来日程（避免重复叠加）
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: semesterStartDate) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: semesterStartDate, end: oneYearLater, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate)
        for oldEvent in existingEvents {
            try? eventStore.remove(oldEvent, span: .futureEvents, commit: false)
        }

        var syncedCount = 0
        let cal = Calendar.current

        // 2. 依次创建每门课的重复事件
        for course in courses where course.isEnabled {
            // 计算第一节课的具体日期
            // course.weekday: 1=周一, 7=周日
            let firstOccurrenceDate = calculateFirstDate(
                weekday: course.weekday,
                semesterStartDate: semesterStartDate,
                startWeek: course.startWeek,
                endWeek: course.endWeek,
                weekMode: course.weekMode
            )

            guard let firstDate = firstOccurrenceDate else { continue }

            var startComp = cal.dateComponents([.year, .month, .day], from: firstDate)
            startComp.hour = course.startHour
            startComp.minute = course.startMinute
            guard let eventStart = cal.date(from: startComp) else { continue }

            var endComp = cal.dateComponents([.year, .month, .day], from: firstDate)
            endComp.hour = course.endHour
            endComp.minute = course.endMinute
            guard let eventEnd = cal.date(from: endComp) else { continue }

            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = course.name
            event.location = course.classroom.isEmpty ? "教室" : course.classroom
            event.notes = "授课教师: \(course.teacher.isEmpty ? "未指定" : course.teacher)\n周数规则: \(course.weekModeDisplay)\n—— 由「QIAN YU (千语伴行)」同步"
            event.startDate = eventStart
            event.endDate = eventEnd

            // 课前智能闹钟
            if course.remindBeforeMinutes > 0 {
                let alarm = EKAlarm(relativeOffset: -Double(course.remindBeforeMinutes * 60))
                event.addAlarm(alarm)
            }

            // 设置周期性重复规则 (Recurrence Rule)
            var repeatCount = 0
            for w in course.startWeek...course.endWeek {
                if course.isActive(inWeek: w) {
                    repeatCount += 1
                }
            }

            if repeatCount > 1 {
                let interval = (course.weekMode == .all) ? 1 : 2
                let recurrenceRule = EKRecurrenceRule(
                    recurrenceWith: .weekly,
                    interval: interval,
                    end: EKRecurrenceEnd(occurrenceCount: repeatCount)
                )
                event.addRecurrenceRule(recurrenceRule)
            }

            try eventStore.save(event, span: .futureEvents, commit: false)
            syncedCount += 1
        }

        try eventStore.commit()
        return syncedCount
    }

    /// 根据星期几和开学起止周数推算第一节课的具体日期
    private func calculateFirstDate(
        weekday: Int,
        semesterStartDate: Date,
        startWeek: Int,
        endWeek: Int,
        weekMode: CourseWeekMode
    ) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 强制周一为每周第一天，消除不同系统区域的周日起始偏移

        // 确定开学周所在周一
        guard let semesterMonday = cal.dateInterval(of: .weekOfYear, for: semesterStartDate)?.start else {
            return nil
        }

        // 计算目标起止周
        var targetWeek = startWeek
        if weekMode == .evenOnly && targetWeek % 2 != 0 {
            targetWeek += 1 // 仅双周但起始周为单周，顺延一周
        } else if weekMode == .oddOnly && targetWeek % 2 == 0 {
            targetWeek += 1 // 仅单周但起始周为双周，顺延一周
        }

        guard targetWeek <= endWeek else {
            return nil
        }

        let weekOffsetDays = (targetWeek - 1) * 7
        let dayOffset = weekday - 1 // 0=周一, 6=周日

        return cal.date(byAdding: .day, value: weekOffsetDays + dayOffset, to: semesterMonday)
    }
}

public enum CalendarSyncError: LocalizedError {
    case permissionDenied
    case failedToSave

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未能获取日历访问权限。请前往系统「设置」->「隐私与安全性」->「日历」中允许 QIAN YU 访问。"
        case .failedToSave:
            return "保存日历事件失败，请稍后重试。"
        }
    }
}
