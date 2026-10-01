#if os(iOS)
import AppIntents
import SwiftData

struct SleepEndedIntent: AppIntent {
    static var title: LocalizedStringResource = "睡眠已结束"
    static var description = IntentDescription("退出睡眠专注模式时，发送千语的清晨问候。")

    @MainActor func perform() async throws -> some IntentResult {
        try await SleepNotificationActions.run(entering: false)
        return .result()
    }
}

struct SleepStartedIntent: AppIntent {
    static var title: LocalizedStringResource = "准备睡觉"
    static var description = IntentDescription("进入睡眠专注模式时，发送千语的晚安问候。")

    @MainActor func perform() async throws -> some IntentResult {
        try await SleepNotificationActions.run(entering: true)
        return .result()
    }
}

@MainActor private enum SleepNotificationActions {
    static func run(entering: Bool) async throws {
        let courses = try QianYuApp.sharedContainer.mainContext.fetch(FetchDescriptor<CourseItem>())
        NotificationManager.shared.primeDailyContent(courses: courses)
        try await NotificationManager.shared.handleSleepTransition(entering: entering)
        await withCheckedContinuation { continuation in
            CourseReminderService.shared.syncAllCourseReminders(courses: courses) { continuation.resume() }
        }
        CourseReminderBackgroundRefresh.schedule()
    }
}

struct SleepNotificationShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SleepEndedIntent(), phrases: ["告诉\(.applicationName)睡眠已结束"],
                    shortTitle: "睡眠已结束", systemImageName: "sunrise")
        AppShortcut(intent: SleepStartedIntent(), phrases: ["告诉\(.applicationName)准备睡觉"],
                    shortTitle: "准备睡觉", systemImageName: "moon")
    }
}
#endif
