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

public struct PomodoroActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Absolute deadline lets the system render time while the app is suspended.
        /// Optional so activities created by older app versions still decode.
        public var endDate: Date?
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
            quote: String = "当破即破，冲冲冲！",
            endDate: Date? = nil
        ) {
            self.endDate = isPaused ? nil : endDate
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

        public var timerInterval: ClosedRange<Date>? {
            guard !isPaused, totalSeconds > 0, let endDate else { return nil }
            return endDate.addingTimeInterval(-Double(totalSeconds))...endDate
        }

        public func remainingSeconds(at date: Date) -> Int {
            guard !isPaused, let endDate else { return max(0, remainingSeconds) }
            return max(0, Int(ceil(endDate.timeIntervalSince(date))))
        }

        public func progress(at date: Date) -> Double {
            guard totalSeconds > 0 else { return 0 }
            let elapsed = Double(totalSeconds - remainingSeconds(at: date))
            return max(0, min(1, elapsed / Double(totalSeconds)))
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

#if canImport(ActivityKit) && os(iOS)
extension PomodoroActivityAttributes: ActivityAttributes {}
#endif
