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

    public func startPomodoro(sessionTitle: String, totalSeconds: Int, remainingSeconds: Int) {
        #if canImport(ActivityKit) && os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 先清理可能残存的旧活动
        endPomodoro()

        let attributes = PomodoroActivityAttributes(sessionName: "千语伴读专注")
        let initialState = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            isPaused: false,
            sessionTitle: sessionTitle
        )

        do {
            let activity = try Activity<PomodoroActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("启动灵动岛实时活动失败: \(error)")
        }
        #endif
    }

    public func updatePomodoro(remainingSeconds: Int, isPaused: Bool, sessionTitle: String) {
        #if canImport(ActivityKit) && os(iOS)
        let activity = currentActivity ?? Activity<PomodoroActivityAttributes>.activities.first
        guard let activeActivity = activity else { return }
        self.currentActivity = activeActivity

        let updatedState = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: activeActivity.content.state.totalSeconds,
            isPaused: isPaused,
            sessionTitle: sessionTitle
        )

        Task {
            await activeActivity.update(.init(state: updatedState, staleDate: nil))
        }
        #endif
    }

    public func endPomodoro() {
        #if canImport(ActivityKit) && os(iOS)
        Task {
            for activity in Activity<PomodoroActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
        #endif
    }
}
