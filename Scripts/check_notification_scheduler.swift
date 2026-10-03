import Foundation
import UserNotifications

@MainActor final class FakeNotificationStore: NotificationRequestStore {
    var requests: [String: UNNotificationRequest] = [:]
    var rejected: Set<String> = []
    func pending() async -> [UNNotificationRequest] {
        await Task.yield()
        return Array(requests.values)
    }
    func add(_ request: UNNotificationRequest) async throws {
        if rejected.contains(request.identifier) { throw NSError(domain: "fixture", code: 1) }
        requests[request.identifier] = request
    }
    func remove(identifiers: [String]) { for id in identifiers { requests[id] = nil } }
}

@main enum NotificationSchedulingChecks {
    @MainActor static func main() async {
        let store = FakeNotificationStore()
        let scheduler = NotificationScheduler(store: store)
        func request(_ id: String) -> UNNotificationRequest {
            UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(), trigger: nil)
        }
        var checks = 0
        func check(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        store.requests["QIANYU_POMODORO_COMPLETE"] = request("QIANYU_POMODORO_COMPLETE")
        store.requests["qianyu_test"] = request("qianyu_test")
        store.requests["qianyu_daily_old"] = request("qianyu_daily_old")
        store.requests["qianyu_course_old"] = request("qianyu_course_old")
        let daily = (0..<35).map { request("qianyu_daily_\($0)") }
        let courses = (0..<80).map { request("qianyu_course_\($0)") }
        await scheduler.enqueue { await scheduler.replacePlan(daily: daily, courses: courses) }.value
        check(store.requests.count == 64, "shared capacity")
        check(store.requests["QIANYU_POMODORO_COMPLETE"] != nil && store.requests["qianyu_test"] != nil, "unrelated notifications retained")
        check(store.requests["qianyu_daily_old"] == nil && store.requests["qianyu_course_old"] == nil, "old owned plan replaced")
        check(daily.allSatisfy { store.requests[$0.identifier] != nil }, "daily slots reserved")
        check(store.requests["qianyu_course_26"] != nil && store.requests["qianyu_course_27"] == nil, "nearest course candidates kept")
        await scheduler.enqueue { await scheduler.replacePlan(daily: daily, courses: courses) }.value
        check(store.requests.count == 64, "repeated schedule does not duplicate")
        let first = scheduler.enqueue { await scheduler.replacePlan(daily: [request("qianyu_daily_first")], courses: []) }
        let second = scheduler.enqueue { await scheduler.replacePlan(daily: [request("qianyu_daily_last")], courses: []) }
        await first.value
        await second.value
        check(store.requests["qianyu_daily_first"] == nil && store.requests["qianyu_daily_last"] != nil, "latest queued plan wins")
        await scheduler.enqueue { await scheduler.remove { $0.hasPrefix("qianyu_daily_") } }.value
        check(store.requests.count == 2, "scoped removal preserves timer and test")
        store.requests = Dictionary(uniqueKeysWithValues: (0..<64).map { ("unrelated-\($0)", request("unrelated-\($0)")) })
        await scheduler.enqueue { await scheduler.replacePlan(daily: daily, courses: courses) }.value
        check(store.requests.count == 64 && store.requests["qianyu_daily_0"] == nil, "no capacity does not evict unrelated requests")
        store.requests = [:]
        store.rejected = ["qianyu_daily_failure"]
        await scheduler.enqueue {
            await scheduler.replacePlan(daily: [request("qianyu_daily_failure"), request("qianyu_daily_success")], courses: [])
        }.value
        check(store.requests["qianyu_daily_success"] != nil, "one failed addition does not block later requests")
        await scheduler.waitUntilIdle()
        print("Notification scheduling checks passed: \(checks)")
    }
}
