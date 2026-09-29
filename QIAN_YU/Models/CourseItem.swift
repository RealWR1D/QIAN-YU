//
//  CourseItem.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftData
import SwiftUI

@Model
public final class CourseItem: Identifiable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var classroom: String = ""
    public var teacher: String = ""
    /// 1 = 周一, 2 = 周二, 3 = 周三, 4 = 周四, 5 = 周五, 6 = 周六, 7 = 周日
    public var weekday: Int = 1
    public var startHour: Int = 8
    public var startMinute: Int = 0
    public var endHour: Int = 9
    public var endMinute: Int = 40
    public var remindBeforeMinutes: Int = 15 // 提前多少分钟提醒，例如 15
    public var isEnabled: Bool = true
    public var colorHex: String = "#FF9500"
    /// 单双周规则: "all" (每周), "oddOnly" (仅单周), "evenOnly" (仅双周)
    public var weekModeRaw: String = "all"
    public var startWeek: Int = 1
    public var endWeek: Int = 16
    /// 包含的具体周数（逗号分隔，如 "2,3,4,5,7,8,10,11,12"）。非空时最高优先级生效
    public var activeWeeksRaw: String = ""

    public init(
        id: UUID = UUID(),
        name: String,
        classroom: String = "",
        teacher: String = "",
        weekday: Int = 1,
        startHour: Int = 8,
        startMinute: Int = 0,
        endHour: Int = 9,
        endMinute: Int = 40,
        remindBeforeMinutes: Int = 15,
        isEnabled: Bool = true,
        colorHex: String = "#FF9500",
        weekModeRaw: String = "all",
        startWeek: Int = 1,
        endWeek: Int = 16,
        activeWeeksRaw: String = ""
    ) {
        self.id = id
        self.name = name
        self.classroom = classroom
        self.teacher = teacher
        self.weekday = weekday
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.remindBeforeMinutes = remindBeforeMinutes
        self.isEnabled = isEnabled
        self.colorHex = colorHex
        self.weekModeRaw = weekModeRaw
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.activeWeeksRaw = activeWeeksRaw
    }

    public var weekdayName: String {
        switch weekday {
        case 1: return String(localized: "周一")
        case 2: return String(localized: "周二")
        case 3: return String(localized: "周三")
        case 4: return String(localized: "周四")
        case 5: return String(localized: "周五")
        case 6: return String(localized: "周六")
        case 7: return String(localized: "周日")
        default: return String(localized: "周一")
        }
    }

    public var formattedTime: String {
        let start = String(format: "%02d:%02d", startHour, startMinute)
        let end = String(format: "%02d:%02d", endHour, endMinute)
        return "\(start) - \(end)"
    }

    public var startTotalMinutes: Int {
        return startHour * 60 + startMinute
    }

    public var endTotalMinutes: Int {
        return endHour * 60 + endMinute
    }

    /// 计算指定日期是否是该课程所在的星期几且当前教学周生效
    public func isScheduledForToday(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        let weekdayIndex = calendar.component(.weekday, from: date)
        // 转为 1=周一 ... 7=周日
        let customWeekday = weekdayIndex == 1 ? 7 : weekdayIndex - 1
        let currentWeek = AppSettings.shared.currentWeekNumber(from: date)
        return customWeekday == self.weekday && isActive(inWeek: currentWeek)
    }

    /// 距离今日上课还有多少分钟 (仅当今天有这节课且尚未结束时有效)
    public func minutesUntilClassToday(from date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard isScheduledForToday(on: date, calendar: calendar) else { return nil }
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentTotal = currentHour * 60 + currentMinute

        if currentTotal < startTotalMinutes {
            return startTotalMinutes - currentTotal
        } else if currentTotal <= endTotalMinutes {
            return 0 // 正在上课
        } else {
            return nil // 已经下课
        }
    }

    /// 生成适合在通知和陪伴界面展示的千语提示语
    public var qianyuReminderMessage: String {
        let loc = classroom.isEmpty ? String(localized: "教室") : classroom
        return EditorialCopy.text("notification.course.pre.body", [
            "courseName": name, "classroom": loc, "minutes": remindBeforeMinutes
        ])
    }

    public var swiftUIColor: Color {
        Color(hex: colorHex)
    }

    public var weekMode: CourseWeekMode {
        get { CourseWeekMode(rawValue: weekModeRaw) ?? .all }
        set { weekModeRaw = newValue.rawValue }
    }

    /// 具体生效的周数集合（如 [2, 3, 4, 5, 7, 8, 10, 11, 12]）
    public var activeWeeks: Set<Int> {
        get {
            guard !activeWeeksRaw.isEmpty else { return [] }
            let nums = activeWeeksRaw.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return Set(nums)
        }
        set {
            activeWeeksRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// 判断课程在指定周数是否生效（优先依照具体周数集合，否则依照起止周与单双周范围）
    public func isActive(inWeek week: Int) -> Bool {
        let explicit = activeWeeks
        if !explicit.isEmpty {
            return explicit.contains(week)
        }
        guard week >= startWeek && week <= endWeek else { return false }
        switch weekMode {
        case .all:
            return true
        case .oddOnly:
            return week % 2 != 0
        case .evenOnly:
            return week % 2 == 0
        }
    }

    public var weekModeDisplay: String {
        let explicit = activeWeeks
        if !explicit.isEmpty {
            return Self.formatWeeksSummary(explicit)
        }
        let span = String(localized: "\(startWeek)-\(endWeek)周")
        switch weekMode {
        case .all: return String(localized: "\(span) · 每周")
        case .oddOnly: return String(localized: "\(span) · 仅单周")
        case .evenOnly: return String(localized: "\(span) · 仅双周")
        }
    }

    /// 将周数集合格式化为优雅的中文字符串，如 "第2-5, 7-8, 10-12周"、"第9周 (单次)"、"第6, 8, 12周 · 双周"
    public static func formatWeeksSummary(_ weeks: Set<Int>) -> String {
        let sorted = weeks.sorted()
        guard !sorted.isEmpty else { return String(localized: "无周次") }
        if sorted.count == 1 {
            return String(localized: "第\(sorted[0])周 (单次)")
        }
        var ranges: [String] = []
        var rStart = sorted[0]
        var rPrev = sorted[0]
        for w in sorted.dropFirst() {
            if w == rPrev + 1 {
                rPrev = w
            } else {
                ranges.append(rStart == rPrev ? "\(rStart)" : "\(rStart)-\(rPrev)")
                rStart = w
                rPrev = w
            }
        }
        ranges.append(rStart == rPrev ? "\(rStart)" : "\(rStart)-\(rPrev)")

        let isAllOdd = sorted.allSatisfy { $0 % 2 != 0 }
        let isAllEven = sorted.allSatisfy { $0 % 2 == 0 }
        var tag = ""
        if isAllOdd && sorted.count > 1 && ranges.count > 1 {
            tag = String(localized: " · 单周")
        } else if isAllEven && sorted.count > 1 && ranges.count > 1 {
            tag = String(localized: " · 双周")
        }

        return String(localized: "第\(ranges.joined(separator: ", "))周\(tag)")
    }

    /// 课后贴心关怀与收尾提醒语
    public func postClassReminderMessage(nextCourse: CourseItem? = nil) -> String {
        let base = EditorialCopy.text("notification.course.post.base", ["courseName": name])
        if let next = nextCourse {
            let nextLoc = next.classroom.isEmpty ? String(localized: "下个教室") : next.classroom
            return EditorialCopy.text("notification.course.post.next", [
                "base": base, "nextCourseName": next.name, "classroom": nextLoc
            ])
        } else {
            return EditorialCopy.text("notification.course.post.done", ["base": base])
        }
    }
}

public enum CourseWeekMode: String, CaseIterable, Identifiable, Codable {
    case all = "all"
    case oddOnly = "oddOnly"
    case evenOnly = "evenOnly"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return String(localized: "每周 (单双周均上)")
        case .oddOnly: return String(localized: "仅单周")
        case .evenOnly: return String(localized: "仅双周")
        }
    }

    public var shortBadge: String {
        switch self {
        case .all: return String(localized: "全周")
        case .oddOnly: return String(localized: "单周")
        case .evenOnly: return String(localized: "双周")
        }
    }
}

// 颜色转换辅助
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 149, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
