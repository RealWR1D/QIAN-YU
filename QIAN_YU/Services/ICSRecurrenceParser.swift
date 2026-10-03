import Foundation

/// Internal stage of the ICS import pipeline.
enum ICSRecurrenceParser {
    static func parseActiveWeeks(
        props: [String: (params: [String: String], value: String)],
        startDate: Date,
        semesterStartDate: Date,
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
        let semStart = semesterStartDate
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
                } else if let date = ICSFileDecoder.parseDate(value, tzid: property.params["TZID"] ?? props["DTSTART"]?.params["TZID"]) {
                    excludedInstants.insert(date)
                }
            }
        }

        let semesterMonday = CourseTimeRules.monday(containing: semStart, calendar: calendar)
        let eventMonday = CourseTimeRules.monday(containing: startDate, calendar: calendar)
        let startWeek = CourseTimeRules.teachingWeek(on: startDate, semesterStart: semStart, calendar: calendar)
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
        let startWeekday = CourseTimeRules.weekday(on: startDate, calendar: calendar)
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
                    activeWeeks.insert(CourseTimeRules.displayWeek(on: occurrenceMonday, semesterStart: semStart, calendar: calendar))
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

    static func parseRecurrenceUntil(_ value: String, timeZone: TimeZone) -> Date? {
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
        return ICSFileDecoder.parseDate(trimmed, tzid: trimmed.hasSuffix("Z") ? nil : timeZone.identifier)
    }

    static func parseWeeksString(_ str: String) -> Set<Int> {
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

    static func extractByDays(from rrule: String) -> [Int] {
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
}
