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
        print("ICS import checks passed: external routing, Unicode/uppercase files, repeat imports, invalid/missing files, picker recovery, no unconfirmed writes")
    }
}
