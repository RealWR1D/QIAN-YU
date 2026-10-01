//
//  LiveActivityManager.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    #if canImport(ActivityKit) && os(iOS)
    private var currentActivity: Activity<PomodoroActivityAttributes>?
    #endif

    private init() {}

    public var hasActiveActivity: Bool {
        #if canImport(ActivityKit) && os(iOS)
        return currentActivity != nil || !Activity<PomodoroActivityAttributes>.activities.isEmpty
        #else
        return false
        #endif
    }

    @discardableResult
    public func startPomodoro(
        sessionTitle: String,
        totalSeconds: Int,
        remainingSeconds: Int,
        endDate: Date,
        quote: String = EditorialCopy.text("focus.activity.defaultQuote")
    ) -> Bool {
        #if canImport(ActivityKit) && os(iOS)
        let areEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        NSLog("📢 [LiveActivityManager] startPomodoro called. areActivitiesEnabled = %d", areEnabled ? 1 : 0)
        if !areEnabled {
            NSLog("⚠️ [LiveActivityManager] 警告: areActivitiesEnabled 为 false，但仍尝试启动实时活动")
        }

        // 先清理可能残存的旧活动
        endPomodoro()

        let attributes = PomodoroActivityAttributes(sessionName: EditorialCopy.text("focus.activity.name"))
        let initialState = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            isPaused: false,
            sessionTitle: sessionTitle,
            quote: quote,
            endDate: endDate
        )

        do {
            let activity = try Activity<PomodoroActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: endDate),
                pushType: nil
            )
            self.currentActivity = activity
            NSLog("✅ [LiveActivityManager] 灵动岛实时活动已成功启动: %@", activity.id)
            return true
        } catch {
            NSLog("❌ [LiveActivityManager] 启动灵动岛实时活动失败: %@", error.localizedDescription)
            return false
        }
        #else
        return false
        #endif
    }

    public func updatePomodoro(
        remainingSeconds: Int,
        isPaused: Bool,
        sessionTitle: String,
        endDate: Date? = nil,
        quote: String? = nil
    ) {
        #if canImport(ActivityKit) && os(iOS)
        let activity = currentActivity ?? Activity<PomodoroActivityAttributes>.activities.first
        guard let activeActivity = activity else { return }
        self.currentActivity = activeActivity

        let finalQuote = quote ?? activeActivity.content.state.quote
        let updatedState = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: activeActivity.content.state.totalSeconds,
            isPaused: isPaused,
            sessionTitle: sessionTitle,
            quote: finalQuote,
            endDate: isPaused ? nil : endDate
        )

        Task {
            await activeActivity.update(.init(state: updatedState, staleDate: updatedState.endDate))
        }
        #endif
    }

    public func endPomodoro() {
        #if canImport(ActivityKit) && os(iOS)
        // 在启动下一次活动前捕获当前集合；不要在异步 Task 执行时重新读取，
        // 否则刚创建的新活动也可能被这次清理结束。
        let activitiesToEnd = Activity<PomodoroActivityAttributes>.activities
        self.currentActivity = nil
        Task {
            for activity in activitiesToEnd {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
