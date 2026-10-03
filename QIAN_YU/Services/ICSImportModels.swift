import Foundation

/// 从 .ics 解析出的课程草稿条目
public struct ParsedCourse: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var classroom: String
    public var teacher: String
    /// 1 = 周一, 2 = 周二, 3 = 周三, 4 = 周四, 5 = 周五, 6 = 周六, 7 = 周日
    public var weekday: Int
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var colorHex: String
    public var occurrencesCount: Int // 在日历中扫描到的重复周次/场次
    public var rawSummary: String
    public var isSelected: Bool

    // 分周相关属性
    public var activeWeeks: Set<Int>
    public var startWeek: Int
    public var endWeek: Int
    public var weekModeRaw: String

    public init(
        id: UUID = UUID(),
        name: String,
        classroom: String = "",
        teacher: String = "",
        weekday: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        colorHex: String = "#FF9500",
        occurrencesCount: Int = 1,
        rawSummary: String = "",
        isSelected: Bool = true,
        activeWeeks: Set<Int> = [],
        startWeek: Int = 1,
        endWeek: Int = 16,
        weekModeRaw: String = "all"
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
        self.colorHex = colorHex
        self.occurrencesCount = occurrencesCount
        self.rawSummary = rawSummary
        self.isSelected = isSelected
        self.activeWeeks = activeWeeks
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.weekModeRaw = weekModeRaw
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
        startHour * 60 + startMinute
    }

    public var endTotalMinutes: Int {
        endHour * 60 + endMinute
    }

    public var weekModeDisplay: String {
        if !activeWeeks.isEmpty {
            return CourseItem.formatWeeksSummary(activeWeeks)
        }
        return String(localized: "\(startWeek)-\(endWeek)周")
    }

    public func toCourseItem(remindBeforeMinutes: Int = 15) -> CourseItem {
        CourseItem(
            name: name,
            classroom: classroom,
            teacher: teacher,
            weekday: weekday,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            remindBeforeMinutes: remindBeforeMinutes,
            isEnabled: true,
            colorHex: colorHex,
            weekModeRaw: weekModeRaw,
            startWeek: startWeek,
            endWeek: endWeek,
            activeWeeksRaw: activeWeeks.sorted().map(String.init).joined(separator: ",")
        )
    }
}

/// 解析结果统计
public struct ICSParseResult {
    public var calendarName: String?
    public var totalEventsCount: Int
    public var courses: [ParsedCourse]
    public var skippedAllDayEventsCount: Int
    public var detectedSemesterStartDate: Date?
    public var detectedSemesterStartDescription: String?

    public var uniqueCoursesCount: Int {
        courses.count
    }
}

public enum ICSParserError: LocalizedError {
    case fileCannotBeRead
    case noValidEventsFound

    public var errorDescription: String? {
        switch self {
        case .fileCannotBeRead:
            return String(localized: "无法读取日历文件，文件可能已损坏或编码不受支持。")
        case .noValidEventsFound:
            return String(localized: "未能从该日历文件中识别出有效的上课日程事件。")
        }
    }
}


// VEVENT properties shared by decoder, recurrence expansion and conversion.
typealias ICSEventProperties = [String: (params: [String: String], value: String)]
