import Foundation

/// Internal stage of the ICS import pipeline.
enum ICSCourseConverter {
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

    static func parseEventProperties(
        _ props: [String: (params: [String: String], value: String)],
        semesterStartDate: Date
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

        guard let startDate = ICSFileDecoder.parseDate(dtstartVal, tzid: tzid) else {
            return (nil, false)
        }

        var endDate: Date?
        if let dtendProp = props["DTEND"] {
            let dtendVal = dtendProp.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let endTzid = dtendProp.params["TZID"] ?? tzid
            endDate = ICSFileDecoder.parseDate(dtendVal, tzid: endTzid)
        } else if let durationProp = props["DURATION"] {
            if let durationMinutes = ICSFileDecoder.parseDurationMinutes(durationProp.value) {
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

        let rawSummary = ICSFileDecoder.unescapeICSText(props["SUMMARY"]?.value ?? String(localized: "未命名课程"))
        let cleanName = cleanCourseName(rawSummary)

        let rawDesc = ICSFileDecoder.unescapeICSText(props["DESCRIPTION"]?.value ?? "")
        var classroom = ICSFileDecoder.unescapeICSText(props["LOCATION"]?.value ?? "")
        if classroom.isEmpty {
            classroom = ICSFileDecoder.unescapeICSText(props["X-HITA-CLASSROOM"]?.value ?? "")
        }
        if classroom.isEmpty {
            classroom = extractClassroomFromDescription(rawDesc)
        }

        var teacher = extractTeacher(fromDescription: rawDesc, orSummary: rawSummary)
        if teacher.isEmpty {
            teacher = ICSFileDecoder.unescapeICSText(props["X-HITA-TEACHER"]?.value ?? "")
        }

        // 解析重复规则中的星期 (RRULE: ...;BYDAY=MO,WE)
        var weekdaysToSchedule: [Int] = []
        if let rruleProp = props["RRULE"] {
            let rruleVal = rruleProp.value
            let byDayMatches = ICSRecurrenceParser.extractByDays(from: rruleVal)
            if !byDayMatches.isEmpty {
                weekdaysToSchedule = byDayMatches
            }
        }

        if weekdaysToSchedule.isEmpty {
            weekdaysToSchedule = [CourseTimeRules.weekday(on: startDate, calendar: cal)]
        }

        var results: [ParsedCourse] = []
        for day in weekdaysToSchedule {
            let activeWeeks = ICSRecurrenceParser.parseActiveWeeks(
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
                name: cleanName.isEmpty ? String(localized: "未命名课程") : cleanName,
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

    static func cleanCourseName(_ name: String) -> String {
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

    static func extractTeacher(fromDescription desc: String, orSummary summary: String) -> String {
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

    static func extractClassroomFromDescription(_ desc: String) -> String {
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

    static func mergeAndDeduplicate(_ drafts: [ParsedCourse]) -> [ParsedCourse] {
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
