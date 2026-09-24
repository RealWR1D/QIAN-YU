//
//  ICSParserService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI

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
        isSelected: Bool = true
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
        startHour * 60 + startMinute
    }

    public var endTotalMinutes: Int {
        endHour * 60 + endMinute
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
            colorHex: colorHex
        )
    }
}

/// 解析结果统计
public struct ICSParseResult {
    public var calendarName: String?
    public var totalEventsCount: Int
    public var courses: [ParsedCourse]
    public var skippedAllDayEventsCount: Int

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
            return "无法读取日历文件，文件可能已损坏或编码不受支持。"
        case .noValidEventsFound:
            return "未能从该日历文件中识别出有效的上课日程事件。"
        }
    }
}

/// iCalendar (.ics) 课表解析引擎
public final class ICSParserService {
    public static let shared = ICSParserService()

    private static let presetColors: [String] = [
        "#FF9500", // 橙 (千语橙)
        "#007AFF", // 蓝
        "#34C759", // 绿
        "#AF52DE", // 紫
        "#FF2D55", // 粉红
        "#5856D6", // 靛蓝
        "#FF9F0A", // 琥珀金
        "#30B0C7", // 青蓝
        "#FF375F", // 桃红
        "#32ADE6"  // 浅海蓝
    ]

    private init() {}

    /// 从 Data 解析日历
    public func parse(data: Data) throws -> ICSParseResult {
        guard let content = Self.decodeDataToString(data) else {
            throw ICSParserError.fileCannotBeRead
        }
        return try parse(content: content)
    }

    /// 从 String 内容解析日历
    public func parse(content: String) throws -> ICSParseResult {
        let unfoldedContent = Self.unfoldICS(content)
        let lines = unfoldedContent.components(separatedBy: .newlines)

        var calendarName: String?
        var totalEvents = 0
        var skippedAllDay = 0
        var rawDrafts: [ParsedCourse] = []

        var inEvent = false
        var currentProperties: [String: (params: [String: String], value: String)] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("X-WR-CALNAME:") {
                let name = String(trimmed.dropFirst("X-WR-CALNAME:".count)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { calendarName = Self.unescapeICSText(name) }
                continue
            }

            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                currentProperties.removeAll()
                continue
            }

            if trimmed == "END:VEVENT" {
                if inEvent {
                    totalEvents += 1
                    let (parsed, isAllDay) = Self.parseEventProperties(currentProperties)
                    if isAllDay {
                        skippedAllDay += 1
                    } else if let parsedCourses = parsed {
                        rawDrafts.append(contentsOf: parsedCourses)
                    }
                    inEvent = false
                    currentProperties.removeAll()
                }
                continue
            }

            if inEvent {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let keyPart = String(trimmed[..<colonIndex])
                    let valuePart = String(trimmed[trimmed.index(after: colonIndex)...])

                    let keyComponents = keyPart.components(separatedBy: ";")
                    let propName = keyComponents[0].uppercased()

                    var params: [String: String] = [:]
                    if keyComponents.count > 1 {
                        for param in keyComponents.dropFirst() {
                            let paramPair = param.components(separatedBy: "=")
                            if paramPair.count == 2 {
                                params[paramPair[0].uppercased()] = paramPair[1].replacingOccurrences(of: "\"", with: "")
                            }
                        }
                    }

                    currentProperties[propName] = (params, valuePart)
                }
            }
        }

        if rawDrafts.isEmpty && totalEvents == 0 {
            throw ICSParserError.noValidEventsFound
        }

        // 进行多周次去重和整合
        let mergedCourses = Self.mergeAndDeduplicate(rawDrafts)

        if mergedCourses.isEmpty && totalEvents > 0 && skippedAllDay == totalEvents {
            throw ICSParserError.noValidEventsFound
        }

        return ICSParseResult(
            calendarName: calendarName,
            totalEventsCount: totalEvents,
            courses: mergedCourses,
            skippedAllDayEventsCount: skippedAllDay
        )
    }

    // MARK: - 辅助方法：多编码尝试解码
    private static func decodeDataToString(_ data: Data) -> String? {
        // 1. UTF-8
        if let str = String(data: data, encoding: .utf8) {
            return str
        }

        // 2. GB18030 (国内高校教务系统常用)
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let str = String(data: data, encoding: gb18030Encoding) {
            return str
        }

        // 3. GBK / GB2312
        let gb2312Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        if let str = String(data: data, encoding: gb2312Encoding) {
            return str
        }

        // 4. UTF-16
        if let str = String(data: data, encoding: .utf16) {
            return str
        }

        // 5. ISO Latin 1 回退
        return String(data: data, encoding: .isoLatin1)
    }

    // MARK: - 辅助方法：展开折叠行 (RFC 5545 Line Unfolding)
    private static func unfoldICS(_ text: String) -> String {
        var res = text.replacingOccurrences(of: "\r\n ", with: "")
        res = res.replacingOccurrences(of: "\r\n\t", with: "")
        res = res.replacingOccurrences(of: "\n ", with: "")
        res = res.replacingOccurrences(of: "\n\t", with: "")
        return res
    }

    // MARK: - 辅助方法：转义字符反转义
    private static func unescapeICSText(_ text: String) -> String {
        var str = text
        str = str.replacingOccurrences(of: "\\\\", with: "\\")
        str = str.replacingOccurrences(of: "\\;", with: ";")
        str = str.replacingOccurrences(of: "\\,", with: ",")
        str = str.replacingOccurrences(of: "\\n", with: "\n")
        str = str.replacingOccurrences(of: "\\N", with: "\n")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 辅助方法：解析单条 VEVENT
    private static func parseEventProperties(
        _ props: [String: (params: [String: String], value: String)]
    ) -> (courses: [ParsedCourse]?, isAllDay: Bool) {
        guard let dtstartProp = props["DTSTART"] else {
            return (nil, false)
        }

        let dtstartVal = dtstartProp.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let tzid = dtstartProp.params["TZID"]

        // 判断是否为全天事件 (只有日期无时间，如 20240902 或包含 VALUE=DATE)
        if dtstartProp.params["VALUE"] == "DATE" || (!dtstartVal.contains("T") && dtstartVal.count == 8) {
            return (nil, true)
        }

        guard let startDate = parseDate(dtstartVal, tzid: tzid) else {
            return (nil, false)
        }

        var endDate: Date?
        if let dtendProp = props["DTEND"] {
            let dtendVal = dtendProp.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let endTzid = dtendProp.params["TZID"] ?? tzid
            endDate = parseDate(dtendVal, tzid: endTzid)
        } else if let durationProp = props["DURATION"] {
            if let durationMinutes = parseDurationMinutes(durationProp.value) {
                endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
            }
        }

        // 若没有结束时间或结束时间异常，默认设置为开始后 45 分钟 (单节标准课时长)
        let resolvedEndDate = endDate ?? startDate.addingTimeInterval(45 * 60)

        let cal = Calendar.current
        let startHour = cal.component(.hour, from: startDate)
        let startMinute = cal.component(.minute, from: startDate)
        let endHour = cal.component(.hour, from: resolvedEndDate)
        let endMinute = cal.component(.minute, from: resolvedEndDate)

        let rawSummary = unescapeICSText(props["SUMMARY"]?.value ?? "未命名课程")
        let cleanName = cleanCourseName(rawSummary)

        let rawDesc = unescapeICSText(props["DESCRIPTION"]?.value ?? "")
        var classroom = unescapeICSText(props["LOCATION"]?.value ?? "")
        if classroom.isEmpty {
            classroom = extractClassroomFromDescription(rawDesc)
        }

        let teacher = extractTeacher(fromDescription: rawDesc, orSummary: rawSummary)

        // 解析重复规则中的星期 (RRULE: ...;BYDAY=MO,WE)
        var weekdaysToSchedule: [Int] = []
        if let rruleProp = props["RRULE"] {
            let rruleVal = rruleProp.value
            let byDayMatches = extractByDays(from: rruleVal)
            if !byDayMatches.isEmpty {
                weekdaysToSchedule = byDayMatches
            }
        }

        if weekdaysToSchedule.isEmpty {
            let weekdayIndex = cal.component(.weekday, from: startDate)
            // 转换 Apple Calendar: 1=Sun, 2=Mon...7=Sat 到 1=周一...7=周日
            let customWeekday = weekdayIndex == 1 ? 7 : weekdayIndex - 1
            weekdaysToSchedule = [customWeekday]
        }

        var results: [ParsedCourse] = []
        for day in weekdaysToSchedule {
            let draft = ParsedCourse(
                name: cleanName.isEmpty ? "未命名课程" : cleanName,
                classroom: classroom,
                teacher: teacher,
                weekday: day,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                occurrencesCount: 1,
                rawSummary: rawSummary,
                isSelected: true
            )
            results.append(draft)
        }

        return (results, false)
    }

    // MARK: - 辅助方法：日期时间解析
    private static func parseDate(_ dateStr: String, tzid: String?) -> Date? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)

        var tz = TimeZone.current
        if trimmed.hasSuffix("Z") {
            tz = TimeZone(secondsFromGMT: 0) ?? .current
        } else if let tzid = tzid, let resolved = TimeZone(identifier: tzid) {
            tz = resolved
        }

        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyyMMdd'T'HHmm'Z'",
            "yyyyMMdd'T'HHmm"
        ]

        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.timeZone = tz
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    // MARK: - 辅助方法：解析 ISO 8601 DURATION
    private static func parseDurationMinutes(_ durationStr: String) -> Int? {
        let str = durationStr.uppercased()
        guard str.hasPrefix("PT") else { return nil }
        var total = 0
        let body = String(str.dropFirst(2))

        // 正则匹配小时与分钟
        if let hRange = body.range(of: #"(\d+)H"#, options: .regularExpression) {
            let hStr = body[hRange].dropLast()
            if let h = Int(hStr) { total += h * 60 }
        }
        if let mRange = body.range(of: #"(\d+)M"#, options: .regularExpression) {
            let mStr = body[mRange].dropLast()
            if let m = Int(mStr) { total += m }
        }

        return total > 0 ? total : nil
    }

    // MARK: - 辅助方法：提取 RRULE 中的 BYDAY
    private static func extractByDays(from rrule: String) -> [Int] {
        let parts = rrule.components(separatedBy: ";")
        for part in parts {
            let kv = part.components(separatedBy: "=")
            if kv.count == 2 && kv[0].uppercased() == "BYDAY" {
                let days = kv[1].components(separatedBy: ",")
                var result: [Int] = []
                for d in days {
                    let cleanD = d.trimmingCharacters(in: .whitespaces).suffix(2).uppercased()
                    switch cleanD {
                    case "MO": result.append(1)
                    case "TU": result.append(2)
                    case "WE": result.append(3)
                    case "TH": result.append(4)
                    case "FR": result.append(5)
                    case "SA": result.append(6)
                    case "SU": result.append(7)
                    default: break
                    }
                }
                return result
            }
        }
        return []
    }

    // MARK: - 辅助方法：清理课程名称中的学期周次标记
    public static func cleanCourseName(_ name: String) -> String {
        var res = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除前缀，如 [课程]、[必修]、[选修]、[通识]
        res = res.replacingOccurrences(
            of: #"^[\[【(（](?:课程|必修|选修|通识|公选|专业课|基础课)[\]】)）]\s*"#,
            with: "",
            options: .regularExpression
        )

        // 移除各种高校教务系统常见的周次后缀，如 (1-16周)、（1-16周(单)）、[第2周]、(周一第1-2节，1-16周)
        res = res.replacingOccurrences(
            of: #"[\[【(（][^\[【(（\]】)）]*?\d+[^\[【(（\]】)）]*?周[^\[【(（\]】)）]*?[\]】)）]"#,
            with: "",
            options: .regularExpression
        )
        res = res.replacingOccurrences(
            of: #"[\[【(（][^\[【(（\]】)）]*?周次?[^\[【(（\]】)）]*?[\]】)）]"#,
            with: "",
            options: .regularExpression
        )

        res = res.trimmingCharacters(in: .whitespacesAndNewlines)
        return res.isEmpty ? name : res
    }

    // MARK: - 辅助方法：智能提取任课教师
    private static func extractTeacher(fromDescription desc: String, orSummary summary: String) -> String {
        // 1. 从 DESCRIPTION 中正则提取: 教师: 张三 / 任课教师：李四 / 讲师: 王五
        let pattern = #"(?:教师|任课教师|授课教师|老师|讲师|Teacher|Instructor)[\s:：]+([^\n\r,;，；\t]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsDesc = desc as NSString
            if let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: nsDesc.length)) {
                let range = match.range(at: 1)
                let t = nsDesc.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }

        // 2. 从 SUMMARY 中提取形如 "课程名-张老师" 或 "课程名(李教授)"
        let summaryTeacherPattern = #"(?:[-–—]\s*|[(（])([^\d\s()（）]{2,4}(?:老师|教授|讲师))[)）]?$"#
        if let regex = try? NSRegularExpression(pattern: summaryTeacherPattern, options: []) {
            let nsSummary = summary as NSString
            if let match = regex.firstMatch(in: summary, options: [], range: NSRange(location: 0, length: nsSummary.length)) {
                let range = match.range(at: 1)
                let t = nsSummary.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }

        return ""
    }

    // MARK: - 辅助方法：从描述中提取教室
    private static func extractClassroomFromDescription(_ desc: String) -> String {
        let pattern = #"(?:教室|地点|上课地点|Location|Room)[\s:：]+([^\n\r,;，；\t]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsDesc = desc as NSString
            if let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: nsDesc.length)) {
                let range = match.range(at: 1)
                return nsDesc.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    // MARK: - 辅助方法：多周次去重和周期性归并
    private static func mergeAndDeduplicate(_ drafts: [ParsedCourse]) -> [ParsedCourse] {
        var grouped: [String: ParsedCourse] = [:]
        var order: [String] = []

        for item in drafts {
            // 分组 key：课程名(小写) + 星期 + 开始时间 + 结束时间
            let key = "\(item.name.lowercased())_\(item.weekday)_\(item.startHour)_\(item.startMinute)_\(item.endHour)_\(item.endMinute)"

            if var existing = grouped[key] {
                existing.occurrencesCount += 1
                if existing.classroom.isEmpty && !item.classroom.isEmpty {
                    existing.classroom = item.classroom
                }
                if existing.teacher.isEmpty && !item.teacher.isEmpty {
                    existing.teacher = item.teacher
                }
                grouped[key] = existing
            } else {
                grouped[key] = item
                order.append(key)
            }
        }

        // 分配视觉统一的课程配色（同名课程共享同一颜色）
        var courseColorMap: [String: String] = [:]
        var colorIndex = 0

        var results: [ParsedCourse] = []
        for key in order {
            guard var course = grouped[key] else { continue }
            let nameKey = course.name.lowercased()
            if let color = courseColorMap[nameKey] {
                course.colorHex = color
            } else {
                let assignedColor = presetColors[colorIndex % presetColors.count]
                courseColorMap[nameKey] = assignedColor
                course.colorHex = assignedColor
                colorIndex += 1
            }
            results.append(course)
        }

        // 排序：先按星期 (1~7)，再按开始时间
        return results.sorted {
            if $0.weekday != $1.weekday {
                return $0.weekday < $1.weekday
            }
            return $0.startTotalMinutes < $1.startTotalMinutes
        }
    }
}
