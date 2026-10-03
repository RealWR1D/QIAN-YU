import Foundation
import UserNotifications

/// System effects are replaceable so scheduling can be checked without real notifications.
@MainActor protocol NotificationRequestStore {
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(identifiers: [String])
}

@MainActor struct SystemNotificationRequestStore: NotificationRequestStore {
    func pending() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
    func remove(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// One owner for the mutation queue and notification capacity.
/// Test notifications and Pomodoro requests retain their existing identifiers and slots.
@MainActor final class NotificationScheduler {
    static let capacity = 64
    let store: any NotificationRequestStore
    private var mutationTask: Task<Void, Never>?

    init(store: (any NotificationRequestStore)? = nil) {
        self.store = store ?? SystemNotificationRequestStore()
    }

    @discardableResult
    func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = mutationTask
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        mutationTask = task
        return task
    }

    func waitUntilIdle() async { await mutationTask?.value }

    static func isManaged(_ identifier: String) -> Bool {
        identifier.hasPrefix("qianyu_course_") || identifier.hasPrefix("qianyu_daily_")
    }

    /// Called inside enqueue. Reserve daily slots, then keep the nearest course reminders.
    func replacePlan(daily: [UNNotificationRequest], courses: [UNNotificationRequest]) async {
        let pending = await store.pending()
        let owned = pending.filter { Self.isManaged($0.identifier) }.map(\.identifier)
        store.remove(identifiers: owned)
        let available = max(0, Self.capacity - (pending.count - owned.count))
        let selectedDaily = Array(daily.prefix(available))
        let selected = selectedDaily + courses.prefix(max(0, available - selectedDaily.count))
        for request in selected {
            do { try await store.add(request) }
            catch { NSLog("安排提醒失败：%@", error.localizedDescription) }
        }
    }

    func remove(where predicate: (String) -> Bool) async {
        let identifiers = await store.pending().map(\.identifier).filter(predicate)
        store.remove(identifiers: identifiers)
    }
}
