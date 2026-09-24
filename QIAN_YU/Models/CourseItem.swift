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
        endWeek: Int = 16
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
    }

    public var weekdayName: String {
        switch weekday {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        case 7: return "周日"
        default: return "周一"
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
        let loc = classroom.isEmpty ? "教室" : classroom
        return "管理员！下节是【\(name)】在【\(loc)】，还有 \(remindBeforeMinutes) 分钟！课本和笔带齐没？走走走，冲冲冲！"
    }

    public var swiftUIColor: Color {
        Color(hex: colorHex)
    }

    public var weekMode: CourseWeekMode {
        get { CourseWeekMode(rawValue: weekModeRaw) ?? .all }
        set { weekModeRaw = newValue.rawValue }
    }

    /// 判断课程在指定周数是否生效（考虑单双周与起止周范围）
    public func isActive(inWeek week: Int) -> Bool {
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
        let span = "\(startWeek)-\(endWeek)周"
        switch weekMode {
        case .all: return "\(span) · 每周"
        case .oddOnly: return "\(span) · 仅单周"
        case .evenOnly: return "\(span) · 仅双周"
        }
    }

    /// 课后贴心关怀与收尾提醒语
    public func postClassReminderMessage(nextCourse: CourseItem? = nil) -> String {
        let base = "「\(name)」下课啦！站起来伸个懒腰接杯水，放松一下肩颈。"
        if let next = nextCourse {
            let nextLoc = next.classroom.isEmpty ? "下个教室" : next.classroom
            return "\(base)下节课是【\(next.name)】，在【\(nextLoc)】，别走错教学楼咯！"
        } else {
            return "\(base)今天后续没有课啦，任务完成！佩剑归鞘，随时喊我闲聊！"
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
        case .all: return "每周 (单双周均上)"
        case .oddOnly: return "仅单周"
        case .evenOnly: return "仅双周"
        }
    }

    public var shortBadge: String {
        switch self {
        case .all: return "全周"
        case .oddOnly: return "单周"
        case .evenOnly: return "双周"
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
