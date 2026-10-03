// Exercises the production file router and parser without sending notifications.
import Foundation
import SwiftUI

@MainActor public final class CourseReminderService {
    public static let shared = CourseReminderService()
    public func syncAllCourseReminders(courses: [CourseItem]) {}
}

@MainActor public final class CalendarSyncService {
    public static let shared = CalendarSyncService()
    public func syncCoursesToSystemCalendar(courses: [CourseItem], semesterStartDate: Date) async throws -> Int { 0 }
}

// The course widget's snapshot types are compiled from its production source.
public struct QianYuChibiMiniAvatarView: View {
    public init(size: CGFloat, assetName: String) {}
    public var body: some View { EmptyView() }
}

@main struct ICSImportChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: 7, to: AppSettings.shared.semesterStartDate)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let day = formatter.string(from: start)
        func fixture(_ name: String) -> String {
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:\(name)\r\nDTSTART:\(day)T080000\r\nDTEND:\(day)T094000\r\nSUMMARY:\(name)\r\nLOCATION:教室 A\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        }
        let first = directory.appendingPathComponent("中文课表.ICS")
        let second = directory.appendingPathComponent("第二份课表.ics")
        try fixture("课程 A").write(to: first, atomically: true, encoding: .utf8)
        try fixture("课程 B").write(to: second, atomically: true, encoding: .utf8)
        let model = CourseScheduleViewModel()
        precondition(!model.handleExternalCalendarURL(URL(string: "qianyu://startPomodoro")!))
        precondition(!model.handleExternalCalendarURL(URL(string: "https://example.com/course.ics")!))
        precondition(!model.handleExternalCalendarURL(directory.appendingPathComponent("readme.txt")))
        precondition(model.externalImportRequestID == nil)

        model.isShowingAddSheet = true
        precondition(model.handleExternalCalendarURL(first))
        precondition(model.isShowingImportPreview && !model.isShowingAddSheet)
        precondition(model.currentImportResult?.courses.first?.name == "课程 A")
        precondition(model.courses.isEmpty, "Sharing must not save courses before confirmation")
        let requestID = model.externalImportRequestID
        let presentationID = model.importPresentationID
        precondition(model.handleExternalCalendarURL(second))
        precondition(model.externalImportRequestID != requestID)
        precondition(model.importPresentationID != presentationID)
        precondition(model.currentImportResult?.courses.first?.name == "课程 B")

        let invalid = directory.appendingPathComponent("损坏.ics")
        try "not a calendar".write(to: invalid, atomically: true, encoding: .utf8)
        precondition(model.handleExternalCalendarURL(invalid))
        precondition(model.isShowingImportErrorAlert && model.importErrorMessage != nil)
        precondition(!model.isShowingImportPreview && model.currentImportResult == nil)
        precondition(model.handleExternalCalendarURL(first))
        precondition(model.isShowingImportPreview && !model.isShowingImportErrorAlert)
        precondition(model.importErrorMessage == nil)
        precondition(model.handleExternalCalendarURL(directory.appendingPathComponent("missing.ics")))
        precondition(model.isShowingImportErrorAlert && model.currentImportResult == nil)
        model.handleFileImportResult(.success(second))
        precondition(model.isShowingImportPreview && !model.isShowingImportErrorAlert)
        precondition(model.currentImportResult?.courses.first?.name == "课程 B")

        // Fixed semester inputs exercise the production recurrence and conversion pipeline.
        let semester = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))!
        func event(_ extra: String = "", uid: String = "fixture", start: String = "20261005T080000",
                   name: String = "测试课程") -> String {
            "BEGIN:VEVENT\r\nUID:\(uid)\r\nDTSTART:\(start)\r\nDURATION:PT1H40M\r\nSUMMARY:\(name)\r\n\(extra)END:VEVENT\r\n"
        }
        func parse(_ events: String) throws -> ICSParseResult {
            try ICSParserService.shared.parse(content: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n\(events)END:VCALENDAR\r\n",
                                              fallbackSemesterStartDate: semester)
        }
        func parserCheck(_ condition: Bool, _ message: String) { precondition(condition, message) }
        func weeks(_ extra: String) throws -> Set<Int> {
            try parse(event(extra)).courses.first?.activeWeeks ?? []
        }
        parserCheck(try weeks("") == [1], "single event does not become a full semester")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;COUNT=3\r\n") == [1, 2, 3], "weekly COUNT")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=3\r\n") == [1, 3, 5], "weekly interval")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;UNTIL=20261019T080000\r\n") == [1, 2, 3], "UNTIL includes boundary")
        let multiple = try parse(event("RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=3\r\n"))
        precondition(multiple.courses.first { $0.weekday == 1 }?.activeWeeks == [1, 2])
        precondition(multiple.courses.first { $0.weekday == 3 }?.activeWeeks == [1], "COUNT counts occurrences across weekdays")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;COUNT=3\r\nEXDATE:20261012T080000\r\n") == [1, 3], "instant EXDATE")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;COUNT=3\r\nEXDATE;VALUE=DATE:20261012\r\n") == [1, 3], "day EXDATE")
        parserCheck(try weeks("RRULE:FREQ=WEEKLY;COUNT=4\r\nEXDATE:20261012T080000\r\nEXDATE:20261019T080000\r\n") == [1, 4], "multiple EXDATE properties")
        let master = event("RRULE:FREQ=WEEKLY;COUNT=3\r\n")
        let changed = try parse(master + event("RECURRENCE-ID:20261012T080000\r\n", start: "20261013T080000"))
        precondition(changed.courses.first { $0.weekday == 1 }?.activeWeeks == [1, 3])
        precondition(changed.courses.first { $0.weekday == 2 }?.activeWeeks == [2], "rescheduled occurrence")
        let cancelled = try parse(master + event("RECURRENCE-ID:20261012T080000\r\nSTATUS:CANCELLED\r\n", start: "20261012T080000"))
        precondition(cancelled.courses.count == 1 && cancelled.courses[0].activeWeeks == [1, 3], "cancelled exception")
        parserCheck(try weeks("X-WEEKS:1,3,6\r\n") == [1, 3, 6], "explicit school weeks")
        let folded = try parse(event("LOCATION:教室\\,A\r\n", name: "测试课\r\n 程"))
        precondition(folded.courses[0].name == "测试课程" && folded.courses[0].classroom == "教室,A", "folding and escaped text")
        precondition(folded.courses[0].endTotalMinutes - folded.courses[0].startTotalMinutes == 100, "DURATION")
        let distinct = try parse(event(name: "体育") + event(uid: "other", name: "体育舞蹈"))
        precondition(distinct.courses.count == 2, "similar course names stay separate")
        let merged = try parse(event() + event(uid: "next", start: "20261012T080000"))
        precondition(merged.courses.count == 1 && merged.courses[0].activeWeeks == [1, 2], "same course merges weeks")
        let allDay = "BEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20261005\r\nSUMMARY:休息日\r\nEND:VEVENT\r\n"
        let mixed = try parse(allDay + event())
        precondition(mixed.totalEventsCount == 2 && mixed.skippedAllDayEventsCount == 1 && mixed.courses.count == 1)
        let beforeSemester = try parse(event(start: "20260928T080000"))
        precondition(beforeSemester.courses.isEmpty, "pre-semester event does not activate week 1")
        print("ICS import checks passed: external routing, Unicode/uppercase files, repeat imports, invalid/missing files, picker recovery, no unconfirmed writes")
        print("ICS parser checks passed: COUNT, INTERVAL, UNTIL, BYDAY, EXDATE, rescheduling, cancellation, explicit weeks, text folding, duration and merging")
    }
}
