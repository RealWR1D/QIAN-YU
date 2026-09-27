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

    public var weekModeDisplay: String {
        if !activeWeeks.isEmpty {
            return CourseItem.formatWeeksSummary(activeWeeks)
        }
        return "\(startWeek)-\(endWeek)周"
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
            return "无法读取日历文件，文件可能已损坏或编码不受支持。"
        case .noValidEventsFound:
            return "未能从该日历文件中识别出有效的上课日程事件。"
        }
    }
}

/// iCalendar (.ics) 课表解析引擎
public final class ICSParserService {
    public static let shared = ICSParserService()
    private typealias EventProperties = [String: (params: [String: String], value: String)]

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
        var eventRecords: [EventProperties] = []

        // 1. 优先自动探测该日历文件对应的学期第一周周一（开学日期）
        let detectedSemesterMonday = Self.detectSemesterStartDate(fromLines: lines, rawContent: unfoldedContent)

        var inEvent = false
        var currentProperties: EventProperties = [:]

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
                    eventRecords.append(currentProperties)
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

                    if propName == "EXDATE", currentProperties[propName] != nil {
                        let nextKey = "EXDATE#\(currentProperties.keys.filter { $0.hasPrefix("EXDATE") }.count)"
                        currentProperties[nextKey] = (params, valuePart)
                    } else {
                        currentProperties[propName] = (params, valuePart)
                    }
                }
            }
        }

        // 先收集全部事件，再将 RECURRENCE-ID 对应的原场次从主重复规则中排除。
        // 调课后的 VEVENT 自身仍按单次事件解析；取消的例外不生成课程。
        let exceptions = eventRecords.filter { $0["RECURRENCE-ID"] != nil }
        for record in eventRecords {
            if record["STATUS"]?.value.uppercased() == "CANCELLED" { continue }
            var properties = record
            if record["RECURRENCE-ID"] == nil, let uid = record["UID"]?.value {
                for exception in exceptions where exception["UID"]?.value == uid {
                    if let originalDate = exception["RECURRENCE-ID"] {
                        properties["EXDATE#EXCEPTION#\(properties.count)"] = originalDate
                    }
                }
            }
            let (parsed, isAllDay) = Self.parseEventProperties(properties, semesterStartDate: detectedSemesterMonday)
            if isAllDay {
                skippedAllDay += 1
            } else if let parsedCourses = parsed {
                rawDrafts.append(contentsOf: parsedCourses)
            }
        }

        if rawDrafts.isEmpty && totalEvents == 0 {
            throw ICSParserError.noValidEventsFound
        }

        // 2. 进行精确周次去重和周期性归并
        let mergedCourses = Self.mergeAndDeduplicate(rawDrafts)

        if mergedCourses.isEmpty && totalEvents > 0 && skippedAllDay == totalEvents {
            throw ICSParserError.noValidEventsFound
        }

        var semesterDesc: String?
        if let sDate = detectedSemesterMonday {
            let df = DateFormatter()
            df.dateFormat = "yyyy年MM月dd日"
            semesterDesc = df.string(from: sDate)
        }

        return ICSParseResult(
            calendarName: calendarName,
            totalEventsCount: totalEvents,
            courses: mergedCourses,
            skippedAllDayEventsCount: skippedAllDay,
            detectedSemesterStartDate: detectedSemesterMonday,
            detectedSemesterStartDescription: semesterDesc
        )
    }

    // MARK: - 辅助方法：自动探测学期开学日期 (第一周周一)
    private static func detectSemesterStartDate(fromLines lines: [String], rawContent: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 周一为每周第一天

        // 1. 尝试从 UID 中探测开学时间戳，例如: ...-202608310000@hita-ios
        if let uidRegex = try? NSRegularExpression(pattern: #"UID:.*?-(\d{8})0000@"#, options: []) {
            let nsContent = rawContent as NSString
            if let match = uidRegex.firstMatch(in: rawContent, options: [], range: NSRange(location: 0, length: nsContent.length)) {
                let dateStr = nsContent.substring(with: match.range(at: 1))
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd"
                if let d = df.date(from: dateStr) {
                    return calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? calendar.startOfDay(for: d)
                }
            }
        }

        // 2. 遍历扫描明确标有第 1 周或包含周数信息的事件
        var candidateEvents: [(date: Date, week: Int)] = []

        var inEv = false
        var dtstartVal: String?
        var weekVal: Int?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "BEGIN:VEVENT" {
                inEv = true
                dtstartVal = nil
                weekVal = nil
                continue
            }
            if trimmed == "END:VEVENT" {
                if let dtStr = dtstartVal, let d = parseDate(dtStr, tzid: nil) {
                    if let w = weekVal {
                        candidateEvents.append((d, w))
                        if w == 1 {
                            // 找到第一周事件，直接提取该事件所属周一
                            return calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? calendar.startOfDay(for: d)
                        }
                    }
                }
                inEv = false
                continue
            }

            if inEv {
                if trimmed.contains("DTSTART") {
                    if let colon = trimmed.firstIndex(of: ":") {
                        dtstartVal = String(trimmed[trimmed.index(after: colon)...])
                    }
                } else if trimmed.contains("X-HITA-WEEKS:") || trimmed.contains("X-WEEKS:") {
                    if let colon = trimmed.firstIndex(of: ":") {
                        let val = String(trimmed[trimmed.index(after: colon)...]).replacingOccurrences(of: "\\,", with: ",")
                        let firstPart = val.components(separatedBy: ",").first ?? ""
                        if let w = Int(firstPart.trimmingCharacters(in: .whitespaces)) {
                            weekVal = w
                        }
                    }
                } else if trimmed.contains("周次") && weekVal == nil {
                    let pattern = #"周次[：:]\s*(?:第\s*)?(\d+)"#
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        let ns = trimmed as NSString
                        if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                            weekVal = Int(ns.substring(with: match.range(at: 1)))
                        }
                    }
                }
            }
        }

        // 如果没有找到第1周，但找到了第 W 周的事件，逆推第1周周一: date - (W - 1) * 7天
        if let firstCandidate = candidateEvents.first {
            let eventMonday = calendar.dateInterval(of: .weekOfYear, for: firstCandidate.date)?.start ?? calendar.startOfDay(for: firstCandidate.date)
            let offsetDays = (firstCandidate.week - 1) * 7
            return calendar.date(byAdding: .day, value: -offsetDays, to: eventMonday)
        }

        return nil
    }

    // MARK: - 辅助方法：多编码尝试解码
    private static func decodeDataToString(_ data: Data) -> String? {
        if let str = String(data: data, encoding: .utf8) { return str }

        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let str = String(data: data, encoding: gb18030Encoding) { return str }

        let gb2312Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        if let str = String(data: data, encoding: gb2312Encoding) { return str }

        if let str = String(data: data, encoding: .utf16) { return str }
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
        _ props: [String: (params: [String: String], value: String)],
        semesterStartDate: Date?
    ) -> (courses: [ParsedCourse]?, isAllDay: Bool) {
        guard let dtstartProp = props["DTSTART"] else {
            return (nil, false)
        }

        let dtstartVal = dtstartProp.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let tzid = dtstartProp.params["TZID"]

        // 判断是否为全天事件
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

        let resolvedEndDate = endDate ?? startDate.addingTimeInterval(45 * 60)

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let startHour = cal.component(.hour, from: startDate)
        let startMinute = cal.component(.minute, from: startDate)
        let endHour = cal.component(.hour, from: resolvedEndDate)
        let endMinute = cal.component(.minute, from: resolvedEndDate)

        let rawSummary = unescapeICSText(props["SUMMARY"]?.value ?? "未命名课程")
        let cleanName = cleanCourseName(rawSummary)

        let rawDesc = unescapeICSText(props["DESCRIPTION"]?.value ?? "")
        var classroom = unescapeICSText(props["LOCATION"]?.value ?? "")
        if classroom.isEmpty {
            classroom = unescapeICSText(props["X-HITA-CLASSROOM"]?.value ?? "")
        }
        if classroom.isEmpty {
            classroom = extractClassroomFromDescription(rawDesc)
        }

        var teacher = extractTeacher(fromDescription: rawDesc, orSummary: rawSummary)
        if teacher.isEmpty {
            teacher = unescapeICSText(props["X-HITA-TEACHER"]?.value ?? "")
        }

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
            // 转换 1=Sun, 2=Mon...7=Sat 到 1=周一...7=周日
            let customWeekday = weekdayIndex == 1 ? 7 : weekdayIndex - 1
            weekdaysToSchedule = [customWeekday]
        }

        var results: [ParsedCourse] = []
        for day in weekdaysToSchedule {
            let activeWeeks = parseActiveWeeks(
                props: props,
                startDate: startDate,
                semesterStartDate: semesterStartDate,
                targetWeekday: day
            )
            if activeWeeks.isEmpty {
                continue
            }

            let minWeek = activeWeeks.min() ?? 1
            let maxWeek = activeWeeks.max() ?? 16
            let isAllOdd = !activeWeeks.isEmpty && activeWeeks.allSatisfy { $0 % 2 != 0 }
            let isAllEven = !activeWeeks.isEmpty && activeWeeks.allSatisfy { $0 % 2 == 0 }
            let weekMode: String = isAllOdd ? "oddOnly" : (isAllEven ? "evenOnly" : "all")
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
                isSelected: true,
                activeWeeks: activeWeeks,
                startWeek: minWeek,
                endWeek: maxWeek,
                weekModeRaw: weekMode
            )
            results.append(draft)
        }

        return (results, false)
    }

    // MARK: - 核心方法：提取精确周数 Set<Int>
    private static func parseActiveWeeks(
        props: [String: (params: [String: String], value: String)],
        startDate: Date,
        semesterStartDate: Date?,
        targetWeekday: Int
    ) -> Set<Int> {
        // 1. 尝试从 X-HITA-WEEKS 或 X-WEEKS 提取 (如 2\,3\,4\,5 或 9 或 10-12)
        for key in ["X-HITA-WEEKS", "X-WEEKS", "X-KONG-WEEKS"] {
            if let wProp = props[key] {
                let val = wProp.value.replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: " ", with: "")
                let weeks = parseWeeksString(val)
                if !weeks.isEmpty {
                    return weeks
                }
            }
        }

        // 2. 尝试从 DESCRIPTION 正则提取: 周次：第 2-5 周 / 周次：第 6,8 周 / 周次: 1-16周(单)
        if let desc = props["DESCRIPTION"]?.value {
            let pattern = #"周次[：:]\s*(?:第\s*)?([0-9\-,，、\\ \n]+)\s*周(?:\s*[（(]([单双])[）)])?"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsDesc = desc as NSString
                if let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: nsDesc.length)) {
                    let rangeStr = nsDesc.substring(with: match.range(at: 1))
                    var weeks = parseWeeksString(rangeStr)
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        let oddEven = nsDesc.substring(with: match.range(at: 2))
                        if oddEven == "单" {
                            weeks = weeks.filter { $0 % 2 != 0 }
                        } else if oddEven == "双" {
                            weeks = weeks.filter { $0 % 2 == 0 }
                        }
                    }
                    if !weeks.isEmpty {
                        return weeks
                    }
                }
            }
        }

        // 3. 尝试从 SUMMARY 正则提取: 微积分(1-16周) / 大学物理[第2周]
        if let summary = props["SUMMARY"]?.value {
            let pattern = #"[\[【(（][^\[【(（]*?(?:第\s*)?([0-9\-,，、\\ ]+)\s*周(?:\s*[（(]?([单双])[）)]?)?[^\]】)）]*?[\]】)）]"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let ns = summary as NSString
                if let match = regex.firstMatch(in: summary, options: [], range: NSRange(location: 0, length: ns.length)) {
                    let rangeStr = ns.substring(with: match.range(at: 1))
                    var weeks = parseWeeksString(rangeStr)
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        let oddEven = ns.substring(with: match.range(at: 2))
                        if oddEven == "单" {
                            weeks = weeks.filter { $0 % 2 != 0 }
                        } else if oddEven == "双" {
                            weeks = weeks.filter { $0 % 2 == 0 }
                        }
                    }
                    if !weeks.isEmpty {
                        return weeks
                    }
                }
            }
        }

        // 4. 依照 DTSTART 与开学日期展开 RRULE。COUNT 表示 occurrence 场次数，
        //    UNTIL 是包含边界；两者都没有时按常见的 16 周学期范围处理。
        // 普通日历文件通常没有学期元数据。此时按用户当前设置的学期
        // 定位单次事件，不能把每条 VEVENT 凭空扩展成 16 周课程。
        let semStart = semesterStartDate ?? AppSettings.shared.semesterStartDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        if let timeZoneID = props["DTSTART"]?.params["TZID"],
           let timeZone = TimeZone(identifier: timeZoneID) {
            calendar.timeZone = timeZone
        }

        var excludedInstants = Set<Date>()
        var excludedDays = Set<String>()
        for (key, property) in props where key.hasPrefix("EXDATE") {
            for rawValue in property.value.components(separatedBy: ",") {
                let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.count == 8, value.allSatisfy(\.isNumber) {
                    excludedDays.insert(value)
                } else if let date = parseDate(value, tzid: property.params["TZID"] ?? props["DTSTART"]?.params["TZID"]) {
                    excludedInstants.insert(date)
                }
            }
        }

        let semesterMonday = calendar.dateInterval(of: .weekOfYear, for: semStart)?.start
            ?? calendar.startOfDay(for: semStart)
        let eventMonday = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start
            ?? calendar.startOfDay(for: startDate)
        let eventOffset = calendar.dateComponents([.day], from: semesterMonday, to: eventMonday).day ?? 0
        let startWeek = (eventOffset / 7) + 1
        guard startWeek > 0 else { return [] }
        guard let rrule = props["RRULE"]?.value else { return [startWeek] }

        var ruleParts: [String: String] = [:]
        for part in rrule.components(separatedBy: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            ruleParts[pair[0].uppercased()] = pair[1]
        }
        guard ruleParts["FREQ"]?.uppercased() == "WEEKLY" else { return [startWeek] }

        let interval = max(1, Int(ruleParts["INTERVAL"] ?? "1") ?? 1)
        let count = ruleParts["COUNT"].flatMap(Int.init)
        if let count, count <= 0 { return [] }

        let until: Date? = ruleParts["UNTIL"].flatMap { value in
            parseRecurrenceUntil(value, timeZone: calendar.timeZone)
        }
        let semesterHorizon = calendar.date(byAdding: .day, value: 16 * 7 - 1, to: semesterMonday)
            ?? semesterMonday
        let horizon = until ?? (count == nil ? semesterHorizon : nil)
        let startWeekdayIndex = calendar.component(.weekday, from: startDate)
        let startWeekday = startWeekdayIndex == 1 ? 7 : startWeekdayIndex - 1
        let recurrenceWeekdays = Set(extractByDays(from: rrule).isEmpty
            ? [startWeekday]
            : extractByDays(from: rrule))
        guard recurrenceWeekdays.contains(targetWeekday) else { return [] }

        var weekAnchor = eventMonday
        var occurrences = 0
        var activeWeeks = Set<Int>()

        for _ in 0..<520 {
            for weekday in recurrenceWeekdays.sorted() {
                guard let dayStart = calendar.date(byAdding: .day, value: weekday - 1, to: weekAnchor) else {
                    continue
                }
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: dayStart)
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = timeComponents.second
                guard let occurrenceDate = calendar.date(from: dateComponents), occurrenceDate >= startDate else {
                    continue
                }
                if let horizon, occurrenceDate > horizon { return activeWeeks }
                if let count, occurrences >= count { return activeWeeks }
                occurrences += 1

                let dayComponents = calendar.dateComponents([.year, .month, .day], from: occurrenceDate)
                let dayKey = String(format: "%04d%02d%02d", dayComponents.year ?? 0, dayComponents.month ?? 0, dayComponents.day ?? 0)
                if excludedInstants.contains(occurrenceDate) || excludedDays.contains(dayKey) {
                    continue
                }

                if weekday == targetWeekday,
                   let occurrenceMonday = calendar.dateInterval(of: .weekOfYear, for: occurrenceDate)?.start {
                    let offset = calendar.dateComponents([.day], from: semesterMonday, to: occurrenceMonday).day ?? 0
                    activeWeeks.insert(max(1, (offset / 7) + 1))
                }
            }

            if let count, occurrences >= count { break }
            guard let nextAnchor = calendar.date(byAdding: .weekOfYear, value: interval, to: weekAnchor) else {
                break
            }
            if let horizon, nextAnchor > horizon { break }
            weekAnchor = nextAnchor
        }

        return activeWeeks
    }

    private static func parseRecurrenceUntil(_ value: String, timeZone: TimeZone) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 8 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyyMMdd"
            guard let day = formatter.date(from: trimmed) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(byAdding: .day, value: 1, to: day)?.addingTimeInterval(-1)
        }
        return parseDate(trimmed, tzid: trimmed.hasSuffix("Z") ? nil : timeZone.identifier)
    }

    /// 解析形如 "2,3,4,5" 或 "2-5" 或 "6,8" 的字符串为 Set<Int>
    private static func parseWeeksString(_ str: String) -> Set<Int> {
        let clean = str
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "第", with: "")
            .replacingOccurrences(of: "周", with: "")

        var result = Set<Int>()
        let segments = clean.components(separatedBy: ",")
        for seg in segments {
            let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("-") || trimmed.contains("~") {
                let rangeParts = trimmed.components(separatedBy: CharacterSet(charactersIn: "-~"))
                if rangeParts.count == 2,
                   let start = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)),
                   start <= end {
                    for w in start...end { result.insert(w) }
                }
            } else if let num = Int(trimmed) {
                result.insert(num)
            }
        }
        return result
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

    // MARK: - 辅助方法：清理课程名称中的学期周次标记与批次后缀
    public static func cleanCourseName(_ name: String) -> String {
        var res = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除前缀，如 [课程]、[必修]、[选修]、[通识]、[实验]、[公选]
        res = res.replacingOccurrences(
            of: #"^[\[【(（](?:课程|必修|选修|通识|公选|专业课|基础课|实验)[\]】)）]\s*"#,
            with: "",
            options: .regularExpression
        )

        // 移除高校教务常见实验批次后缀，如 1批/第2... 或 2批/第2...
        res = res.replacingOccurrences(
            of: #"\s*\d+批(?:/[^\]]+)?"#,
            with: "",
            options: .regularExpression
        )

        // 移除截断提示符如 第X...
        res = res.replacingOccurrences(
            of: #"\s*第\d+\.\.\.\s*"#,
            with: " ",
            options: .regularExpression
        )

        // 移除各种高校教务系统常见的周次后缀，如 (1-16周)、（1-16周(单)）、[第2周]
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
        let pattern = #"(?:教师|任课教师|授课教师|老师|讲师|Teacher|Instructor)[\s:：]+([^\n\r\\;,]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsDesc = desc as NSString
            if let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: nsDesc.length)) {
                let range = match.range(at: 1)
                let t = nsDesc.substring(with: range)
                    .components(separatedBy: "\n")[0]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }

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
        let pattern = #"(?:教室|地点|上课地点|Location|Room)[\s:：]+([^\n\r\\;,]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsDesc = desc as NSString
            if let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: nsDesc.length)) {
                let range = match.range(at: 1)
                return nsDesc.substring(with: range)
                    .components(separatedBy: "\n")[0]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    // MARK: - 辅助方法：精确分周归并与多周次去重
    private static func mergeAndDeduplicate(_ drafts: [ParsedCourse]) -> [ParsedCourse] {
        var merged: [ParsedCourse] = []

        func normalizedCourseName(_ name: String) -> String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .lowercased()
        }

        for item in drafts {
            var foundIndex: Int?

            for (idx, existing) in merged.enumerated() {
                let isSameSlot = (existing.weekday == item.weekday &&
                                  existing.startTotalMinutes == item.startTotalMinutes &&
                                  existing.endTotalMinutes == item.endTotalMinutes &&
                                  existing.classroom == item.classroom)

                guard isSameSlot else { continue }

                // 只归并规范化后完全同名的课程，避免“体育”吞掉“体育舞蹈”等相似名称。
                if normalizedCourseName(existing.name) == normalizedCourseName(item.name) {
                    foundIndex = idx
                    break
                }
            }

            if let idx = foundIndex {
                var existing = merged[idx]
                existing.occurrencesCount += 1
                existing.activeWeeks.formUnion(item.activeWeeks)

                // 若新条目的名称更完整或更长，采用更完整的名称
                if item.name.count > existing.name.count {
                    existing.name = item.name
                }
                if existing.teacher.isEmpty && !item.teacher.isEmpty {
                    existing.teacher = item.teacher
                }
                if existing.classroom.isEmpty && !item.classroom.isEmpty {
                    existing.classroom = item.classroom
                }

                // 更新周次统计
                let minW = existing.activeWeeks.min() ?? 1
                let maxW = existing.activeWeeks.max() ?? 16
                let isOdd = !existing.activeWeeks.isEmpty && existing.activeWeeks.allSatisfy { $0 % 2 != 0 }
                let isEven = !existing.activeWeeks.isEmpty && existing.activeWeeks.allSatisfy { $0 % 2 == 0 }
                existing.startWeek = minW
                existing.endWeek = maxW
                existing.weekModeRaw = isOdd ? "oddOnly" : (isEven ? "evenOnly" : "all")

                merged[idx] = existing
            } else {
                merged.append(item)
            }
        }

        // 分配视觉统一的课程配色（同名课程共享同一颜色）
        var courseColorMap: [String: String] = [:]
        var colorIndex = 0

        for i in merged.indices {
            let nameKey = normalizedCourseName(merged[i].name)
            if let color = courseColorMap[nameKey] {
                merged[i].colorHex = color
            } else {
                let assignedColor = presetColors[colorIndex % presetColors.count]
                courseColorMap[nameKey] = assignedColor
                merged[i].colorHex = assignedColor
                colorIndex += 1
            }
        }

        // 排序：先按星期 (1~7)，再按开始时间
        return merged.sorted {
            if $0.weekday != $1.weekday {
                return $0.weekday < $1.weekday
            }
            return $0.startTotalMinutes < $1.startTotalMinutes
        }
    }
}
