//
//  PomodoroTimerViewModel.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI
import UserNotifications

@Observable
@MainActor
public final class PomodoroTimerViewModel {
    public enum TimerState {
        case idle
        case running
        case paused
        case completed
    }

    public enum SessionMode: String, CaseIterable, Identifiable {
        case focus = "专注"
        case breakTime = "小憩"

        public var id: String { rawValue }
        public var displayName: String {
            EditorialCopy.text(self == .focus ? "focus.mode.focus" : "focus.mode.break")
        }
    }

    // MARK: - 公开属性
    public var state: TimerState = .idle
    public var mode: SessionMode = .focus
    public var selectedMinutes: Int = 25
    public var remainingSeconds: Int = 25 * 60
    public var totalSeconds: Int = 25 * 60

    // 预设时长选项 (分钟)
    public let focusPresets: [Int] = [15, 25, 45, 60]
    public let breakPresets: [Int] = [5, 10, 15]

    // MARK: - 内部计时控制
    private var timerTask: Task<Void, Never>?
    private var targetEndDate: Date?
    private let storagePrefix = "qianyu.pomodoro."

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedMode = defaults.string(forKey: storagePrefix + "mode"),
           let restoredMode = SessionMode(rawValue: savedMode) {
            mode = restoredMode
        }
        let savedMinutes = defaults.integer(forKey: storagePrefix + "minutes")
        if savedMinutes > 0 { selectedMinutes = savedMinutes }
        totalSeconds = selectedMinutes * 60
        remainingSeconds = totalSeconds
        let savedRemaining = defaults.integer(forKey: storagePrefix + "remaining")
        let savedState = defaults.string(forKey: storagePrefix + "state")
        if savedState == "paused", savedRemaining > 0 {
            state = .paused
            remainingSeconds = savedRemaining
        } else if savedState == "running" {
            let end = Date(timeIntervalSince1970: defaults.double(forKey: storagePrefix + "end"))
            if end > Date() {
                targetEndDate = end
                remainingSeconds = Int(ceil(end.timeIntervalSinceNow))
                state = .running
                runTimerLoop()
            } else {
                remainingSeconds = 0
                state = .completed
                persistState()
                #if os(iOS)
                LiveActivityManager.shared.endPomodoro()
                #endif
            }
        } else if savedState == "completed" {
            remainingSeconds = 0
            state = .completed
        }
    }

    private func persistState() {
        defaults.set(mode.rawValue, forKey: storagePrefix + "mode")
        defaults.set(selectedMinutes, forKey: storagePrefix + "minutes")
        defaults.set(remainingSeconds, forKey: storagePrefix + "remaining")
        defaults.set(targetEndDate?.timeIntervalSince1970, forKey: storagePrefix + "end")
        let stateName: String
        switch state {
        case .idle: stateName = "idle"
        case .running: stateName = "running"
        case .paused: stateName = "paused"
        case .completed: stateName = "completed"
        }
        defaults.set(stateName, forKey: storagePrefix + "state")
    }

    // MARK: - 格式化计算属性
    public var formattedTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return max(0.0, min(1.0, elapsed / Double(totalSeconds)))
    }

    public var statusCaption: String {
        switch state {
        case .idle:
            return EditorialCopy.text(mode == .focus ? "focus.idle.focus" : "focus.idle.break")
        case .running:
            return EditorialCopy.text(mode == .focus ? "focus.running.focus" : "focus.running.break")
        case .paused:
            return EditorialCopy.text("focus.paused")
        case .completed:
            return EditorialCopy.text(mode == .focus ? "focus.completed.focus" : "focus.completed.break")
        }
    }

    private var activityTitle: String {
        EditorialCopy.text(mode == .focus ? "focus.activity.focus" : "focus.activity.break")
    }

    // MARK: - 计时器操作
    public func selectMinutes(_ mins: Int) {
        guard state == .idle || state == .completed else { return }
        selectedMinutes = mins
        totalSeconds = mins * 60
        remainingSeconds = totalSeconds
        persistState()
    }

    public func setMode(_ newMode: SessionMode) {
        guard state == .idle || state == .completed else { return }
        mode = newMode
        let defaultMins = (newMode == .focus) ? 25 : 5
        selectMinutes(defaultMins)
    }

    public func start() {
        guard remainingSeconds > 0 else { return }
        state = .running
        let end = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        targetEndDate = end
        persistState()

        // 启动后台/本地通知
        scheduleCompletionNotification()

        #if os(iOS)
        // 联动灵动岛 / 实时活动
        LiveActivityManager.shared.startPomodoro(
            sessionTitle: activityTitle,
            totalSeconds: totalSeconds,
            remainingSeconds: remainingSeconds,
            endDate: end
        )
        #endif

        runTimerLoop()
    }

    public func pause() {
        guard state == .running else { return }
        if let targetEndDate {
            remainingSeconds = max(0, Int(ceil(targetEndDate.timeIntervalSinceNow)))
        }
        if remainingSeconds == 0 {
            completeSession()
            return
        }
        timerTask?.cancel()
        timerTask = nil
        targetEndDate = nil
        state = .paused
        persistState()
        cancelCompletionNotification()

        #if os(iOS)
        LiveActivityManager.shared.updatePomodoro(
            remainingSeconds: remainingSeconds,
            isPaused: true,
            sessionTitle: EditorialCopy.text(mode == .focus ? "focus.activity.focusPaused" : "focus.activity.breakPaused")
        )
        #endif
    }

    public func resume() {
        guard state == .paused, remainingSeconds > 0 else { return }
        state = .running
        let end = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        targetEndDate = end
        persistState()
        scheduleCompletionNotification()

        #if os(iOS)
        if LiveActivityManager.shared.hasActiveActivity {
            LiveActivityManager.shared.updatePomodoro(
                remainingSeconds: remainingSeconds,
                isPaused: false,
                sessionTitle: activityTitle,
                endDate: end
            )
        } else {
            LiveActivityManager.shared.startPomodoro(
                sessionTitle: activityTitle,
                totalSeconds: totalSeconds,
                remainingSeconds: remainingSeconds,
                endDate: end
            )
        }
        #endif

        runTimerLoop()
    }

    public func reset() {
        timerTask?.cancel()
        timerTask = nil
        targetEndDate = nil
        state = .idle
        totalSeconds = selectedMinutes * 60
        remainingSeconds = totalSeconds
        persistState()
        cancelCompletionNotification()

        #if os(iOS)
        LiveActivityManager.shared.endPomodoro()
        #endif
    }

    /// Reconcile immediately on activation, without waiting for the UI timer task.
    public func synchronizeAfterSuspension(now: Date = Date()) {
        guard state == .running, let end = targetEndDate else { return }
        remainingSeconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        guard remainingSeconds > 0 else {
            completeSession()
            return
        }
        #if os(iOS)
        if LiveActivityManager.shared.hasActiveActivity {
            LiveActivityManager.shared.updatePomodoro(
                remainingSeconds: remainingSeconds,
                isPaused: false,
                sessionTitle: activityTitle,
                endDate: end
            )
        } else {
            LiveActivityManager.shared.startPomodoro(
                sessionTitle: activityTitle,
                totalSeconds: totalSeconds,
                remainingSeconds: remainingSeconds,
                endDate: end
            )
        }
        #endif
    }

    private func completeSession() {
        timerTask?.cancel()
        timerTask = nil
        targetEndDate = nil
        remainingSeconds = 0
        state = .completed
        persistState()
        #if os(iOS)
        LiveActivityManager.shared.endPomodoro()
        #endif
    }

    private func runTimerLoop() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 按实际截止时间每秒刷新
                guard !Task.isCancelled else { break }
                guard let self = self, let target = self.targetEndDate else { break }

                let diff = Int(ceil(target.timeIntervalSinceNow))
                if diff <= 0 {
                    self.completeSession()
                    break
                }
                if self.remainingSeconds != diff { self.remainingSeconds = diff }
            }
        }
    }

    // MARK: - 本地通知提示
    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        let key = mode == .focus ? "focus.notification.focus" : "focus.notification.break"
        content.title = EditorialCopy.text("\(key).title")
        content.body = EditorialCopy.text("\(key).body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(remainingSeconds)), repeats: false)
        let request = UNNotificationRequest(identifier: "QIANYU_POMODORO_COMPLETE", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["QIANYU_POMODORO_COMPLETE"])
    }
}
