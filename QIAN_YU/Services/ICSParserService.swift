import Foundation

/// Public import entry point. Decoding, recurrence expansion and course conversion
/// are separate stages; callers can inject a semester date for deterministic imports.
public final class ICSParserService {
    public static let shared = ICSParserService()
    private typealias EventProperties = ICSEventProperties
    private init() {}

    public func parse(data: Data, fallbackSemesterStartDate: Date? = nil) throws -> ICSParseResult {
        guard let content = ICSFileDecoder.decodeDataToString(data) else {
            throw ICSParserError.fileCannotBeRead
        }
        return try parse(content: content, fallbackSemesterStartDate: fallbackSemesterStartDate)
    }

    public func parse(content: String, fallbackSemesterStartDate: Date? = nil) throws -> ICSParseResult {
        let unfoldedContent = ICSFileDecoder.unfoldICS(content)
        let lines = unfoldedContent.components(separatedBy: .newlines)

        var calendarName: String?
        var totalEvents = 0
        var skippedAllDay = 0
        var rawDrafts: [ParsedCourse] = []
        var eventRecords: [EventProperties] = []

        // 1. 优先自动探测该日历文件对应的学期第一周周一（开学日期）
        let detectedSemesterMonday = ICSSemesterDetector.detectSemesterStartDate(fromLines: lines, rawContent: unfoldedContent)

        var inEvent = false
        var currentProperties: EventProperties = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("X-WR-CALNAME:") {
                let name = String(trimmed.dropFirst("X-WR-CALNAME:".count)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { calendarName = ICSFileDecoder.unescapeICSText(name) }
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
            let (parsed, isAllDay) = ICSCourseConverter.parseEventProperties(properties, semesterStartDate: detectedSemesterMonday ?? fallbackSemesterStartDate ?? AppSettings.shared.semesterStartDate)
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
        let mergedCourses = ICSCourseConverter.mergeAndDeduplicate(rawDrafts)

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

    public static func cleanCourseName(_ name: String) -> String {
        ICSCourseConverter.cleanCourseName(name)
    }
}
