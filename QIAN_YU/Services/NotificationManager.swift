//
//  NotificationManager.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import UserNotifications

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

    /// 根据 AppSettings 重新排布每日四大定点陪伴推送
    public func scheduleDailyNotifications() {
        let center = UNUserNotificationCenter.current()
        let settings = AppSettings.shared

        // 移除旧的每日定点通知
        let dailyIds = [
            "qianyu_daily_morning",
            "qianyu_daily_lunch",
            "qianyu_daily_afternoon",
            "qianyu_daily_evening"
        ]
        center.removePendingNotificationRequests(withIdentifiers: dailyIds)

        if settings.morningEnabled {
            scheduleNotification(
                id: "qianyu_daily_morning",
                type: .morning,
                hour: settings.morningHour,
                minute: settings.morningMinute
            )
        }

        if settings.lunchEnabled {
            scheduleNotification(
                id: "qianyu_daily_lunch",
                type: .lunch,
                hour: settings.lunchHour,
                minute: settings.lunchMinute
            )
        }

        if settings.afternoonEnabled {
            scheduleNotification(
                id: "qianyu_daily_afternoon",
                type: .afternoon,
                hour: settings.afternoonHour,
                minute: settings.afternoonMinute
            )
        }

        if settings.eveningEnabled {
            scheduleNotification(
                id: "qianyu_daily_evening",
                type: .evening,
                hour: settings.eveningHour,
                minute: settings.eveningMinute
            )
        }
    }

    private func scheduleNotification(id: String, type: PushType, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        let (title, body) = PersonaEngine.shared.fallbackNotification(
            for: type,
            userName: AppSettings.shared.userName
        )
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "QIANYU_DAILY_MESSAGE"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("安排通知 \(id) 失败: \(error)")
            }
        }
    }

    /// 发送即时测试通知（5秒后触发），方便用户验证推送效果
    public func sendTestNotification(completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "陈千语来信啦！"
        content.body = "「在呢在呢！测试推送成功啦！今天不管上课还是练剑，我都准备好啦，冲冲冲！」"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "qianyu_test_\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    // MARK: - 前台接收通知展示设置
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        #if os(macOS)
        return [.banner, .sound, .badge, .list]
        #else
        return [.banner, .sound, .badge, .list]
        #endif
    }
}
