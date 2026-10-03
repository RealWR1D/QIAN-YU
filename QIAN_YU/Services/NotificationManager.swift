//
//  NotificationManager.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import UserNotifications

@MainActor
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// 请求通知授权
    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("请求通知权限出错: \(error)")
            return false
        }
    }

    /// 检查当前是否已获得授权
    public func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// 仅首次运行时请求权限；已授权或已拒绝时尊重系统中的选择。
    public func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return await requestAuthorization()
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    private let dailyContent = DailyPushContentService()
    private var cachedCourses: [CourseItem] = []
    private let scheduler = NotificationScheduler()
    private let sentKey = "qianyu_daily_sent_v1"

    /// 所有排程和睡眠动作共享队列，避免改设置与自动化同时运行时重复发送。
    @discardableResult
    func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        scheduler.enqueue(operation)
    }

    func cache(courses: [CourseItem]) { cachedCourses = courses }

    public func scheduleDailyNotifications() {
        reschedule(courses: cachedCourses)
    }

    /// A course change, a settings change and a foreground refresh share this path.
    func reschedule(courses: [CourseItem], completion: (() -> Void)? = nil) {
        cache(courses: courses)
        enqueue {
            let courses = self.cachedCourses
            let daily = self.dailyRequests(courses: self.dailyCourseSnapshots(courses: courses))
            let reminders = CourseReminderService.shared.requests(courses: courses, now: Date(), settings: .shared)
            await self.scheduler.replacePlan(daily: daily, courses: reminders)
            self.refreshDailyContent()
            completion?()
        }
    }

    func removePendingRequests(where predicate: @escaping (String) -> Bool) {
        enqueue { await self.scheduler.remove(where: predicate) }
    }

    private var sentIdentifiers: Set<String> {
        let cutoff = Date().addingTimeInterval(-8 * 24 * 60 * 60).timeIntervalSince1970
        let saved = (UserDefaults.standard.dictionary(forKey: sentKey) as? [String: Double] ?? [:])
            .filter { $0.value >= cutoff }
        UserDefaults.standard.set(saved, forKey: sentKey)
        return Set(saved.keys)
    }

    var dailyConfiguration: DailyPushPlanner.Configuration {
        let settings = AppSettings.shared
        return .init(
            morning: settings.morningEnabled ? settings.morningHour * 60 + settings.morningMinute : nil,
            lunch: settings.lunchEnabled ? settings.lunchHour * 60 + settings.lunchMinute : nil,
            afternoon: settings.afternoonEnabled ? settings.afternoonHour * 60 + settings.afternoonMinute : nil,
            dusk: settings.duskEnabled ? settings.duskHour * 60 + settings.duskMinute : nil,
            evening: settings.eveningEnabled ? settings.eveningHour * 60 + settings.eveningMinute : nil,
            followsSleep: settings.sleepAutomationEnabled,
            semesterStart: settings.semesterStartDate
        )
    }

    func dailyCourseSnapshots(courses: [CourseItem]) -> [DailyPushPlanner.Course] {
        courses.filter(\.isEnabled).map(\.scheduleRule)
    }

    func primeDailyContent(courses: [CourseItem]) {
        cache(courses: courses)
        let snapshots = dailyCourseSnapshots(courses: courses)
        let entries = DailyPushPlanner.entries(now: Date(), configuration: dailyConfiguration, courses: snapshots,
                                              sentIdentifiers: sentIdentifiers)
        dailyContent.setPlan(entries: entries, courses: snapshots)
    }

    func dailyRequests(courses: [DailyPushPlanner.Course]) -> [UNNotificationRequest] {
        let entries = DailyPushPlanner.entries(now: Date(), configuration: dailyConfiguration, courses: courses,
                                              sentIdentifiers: sentIdentifiers)
        dailyContent.setPlan(entries: entries, courses: courses)
        return entries.map { request(for: $0, immediate: false) }
    }

    func waitForDailyContentRefresh() async {
        await dailyContent.waitForRefresh()
        await scheduler.waitUntilIdle()
    }

    func refreshDailyContent() {
        dailyContent.refresh { entries in
            self.enqueue {
                let pending = Dictionary(uniqueKeysWithValues: await self.scheduler.store.pending().map { ($0.identifier, $0) })
                for entry in entries where entry.date > Date() && (pending[entry.identifier]?.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == entry.date
                    && !self.sentIdentifiers.contains(entry.identifier) {
                    do { try await self.scheduler.store.add(self.request(for: entry, immediate: false)) }
                    catch { NSLog("更新每日通知文案失败，保留原通知。") }
                }
            }
        }
    }

    private func request(for entry: DailyPushPlanner.Entry, immediate: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let message = dailyContent.message(for: entry)
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = "QIANYU_DAILY_MESSAGE"
        if immediate { return UNNotificationRequest(identifier: entry.identifier, content: content, trigger: nil) }
        var calendar = Calendar.current
        calendar.timeZone = .current
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        return UNNotificationRequest(identifier: entry.identifier, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }

    /// 快捷指令在后台调用；允许一次提前通知，并替换当天的兜底请求。
    func handleSleepTransition(entering: Bool) async throws {
        var failure: Error?
        let task = enqueue {
            let now = Date()
            guard let entry = DailyPushPlanner.sleepEntry(entering: entering, now: now,
                                                         configuration: self.dailyConfiguration),
                  !self.sentIdentifiers.contains(entry.identifier) else { return }
            do {
                try await self.scheduler.store.add(self.request(for: entry, immediate: true))
                var saved = UserDefaults.standard.dictionary(forKey: self.sentKey) as? [String: Double] ?? [:]
                saved[entry.identifier] = now.timeIntervalSince1970
                UserDefaults.standard.set(saved, forKey: self.sentKey)
            } catch { failure = error }
        }
        await task.value
        if let failure { throw failure }
    }

    /// 发送即时测试通知（3秒后触发），方便用户验证推送效果
    public func sendTestNotification(completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = EditorialCopy.text("notification.test.title")
        content.body = EditorialCopy.text("notification.test.body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "qianyu_test", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    // MARK: - 前台接收通知展示设置
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge, .list]
    }
}
