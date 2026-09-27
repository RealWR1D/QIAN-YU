//
//  PomodoroActivityAttributes.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit) && os(iOS)
public struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var isPaused: Bool
        public var sessionTitle: String // e.g. "专注中" 或 "小憩中"
        public var quote: String

        public init(
            remainingSeconds: Int,
            totalSeconds: Int,
            isPaused: Bool,
            sessionTitle: String,
            quote: String = "当破即破，冲冲冲！"
        ) {
            self.remainingSeconds = remainingSeconds
            self.totalSeconds = totalSeconds
            self.isPaused = isPaused
            self.sessionTitle = sessionTitle
            self.quote = quote
        }

        public var formattedTime: String {
            let mins = max(0, remainingSeconds) / 60
            let secs = max(0, remainingSeconds) % 60
            return String(format: "%02d:%02d", mins, secs)
        }

        public var progress: Double {
            guard totalSeconds > 0 else { return 0 }
            let elapsed = Double(totalSeconds - remainingSeconds)
            return max(0.0, min(1.0, elapsed / Double(totalSeconds)))
        }
    }

    public var sessionName: String

    public init(sessionName: String) {
        self.sessionName = sessionName
    }
}
#endif
