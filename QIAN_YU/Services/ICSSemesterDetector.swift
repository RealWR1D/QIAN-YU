import Foundation

/// Internal stage of the ICS import pipeline.
enum ICSSemesterDetector {
    static func detectSemesterStartDate(fromLines lines: [String], rawContent: String) -> Date? {
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
                if let dtStr = dtstartVal, let d = ICSFileDecoder.parseDate(dtStr, tzid: nil) {
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
}
