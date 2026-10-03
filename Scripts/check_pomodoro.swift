import Foundation

// The regression harness exercises the actual model and view model without loading app copy.
enum EditorialCopy {
    static func text(_ key: String) -> String { key }
}

@main
struct PomodoroRegressionCheck {
    @MainActor
    static func main() throws {
        typealias State = PomodoroActivityAttributes.ContentState
        let origin = Date(timeIntervalSince1970: 2_000_000_000)
        let deadline = origin.addingTimeInterval(1500)
        let running = State(remainingSeconds: 1500, totalSeconds: 1500,
                            isPaused: false, sessionTitle: "focus", endDate: deadline)
        // No activity updates arrive during a long suspension.
        precondition(running.remainingSeconds(at: origin.addingTimeInterval(900)) == 600)
        precondition(abs(running.progress(at: origin.addingTimeInterval(900)) - 0.6) < 0.0001)
        precondition(running.remainingSeconds(at: deadline.addingTimeInterval(-0.2)) == 1)
        precondition(running.remainingSeconds(at: deadline.addingTimeInterval(3600)) == 0)
        precondition(running.progress(at: deadline.addingTimeInterval(3600)) == 1)
        precondition(running.timerInterval == origin...deadline)

        let paused = State(remainingSeconds: 600, totalSeconds: 1500,
                           isPaused: true, sessionTitle: "paused", endDate: deadline)
        precondition(paused.timerInterval == nil && paused.endDate == nil)
        precondition(paused.remainingSeconds(at: deadline.addingTimeInterval(3600)) == 600)
        let resumedDeadline = deadline.addingTimeInterval(3600)
        let resumed = State(remainingSeconds: 600, totalSeconds: 1500,
                            isPaused: false, sessionTitle: "focus", endDate: resumedDeadline)
        // Resuming preserves the completed portion of the total session.
        precondition(abs(resumed.progress(at: resumedDeadline.addingTimeInterval(-600)) - 0.6) < 0.0001)
        precondition(resumed.timerInterval?.upperBound == resumedDeadline)
        let decoded = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(resumed))
        precondition(decoded == resumed)
        let legacyData = Data(#"{"remainingSeconds":420,"totalSeconds":1500,"isPaused":false,"sessionTitle":"focus","quote":"legacy"}"#.utf8)
        let legacy = try JSONDecoder().decode(State.self, from: legacyData)
        precondition(legacy.endDate == nil && legacy.formattedTime == "07:00")

        let suite = "qianyu.pomodoro.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let end = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1500)
        defaults.set("running", forKey: "qianyu.pomodoro.state")
        defaults.set(25, forKey: "qianyu.pomodoro.minutes")
        defaults.set(1500, forKey: "qianyu.pomodoro.remaining")
        defaults.set(end.timeIntervalSince1970, forKey: "qianyu.pomodoro.end")
        let timer = PomodoroTimerViewModel(defaults: defaults)
        timer.synchronizeAfterSuspension(now: end.addingTimeInterval(-600))
        precondition(timer.state == .running && timer.remainingSeconds == 600)
        timer.synchronizeAfterSuspension(now: end.addingTimeInterval(300))
        precondition(timer.state == .completed && timer.remainingSeconds == 0)
        precondition(defaults.string(forKey: "qianyu.pomodoro.state") == "completed")
        precondition(defaults.object(forKey: "qianyu.pomodoro.end") == nil)

        defaults.set("paused", forKey: "qianyu.pomodoro.state")
        defaults.set(600, forKey: "qianyu.pomodoro.remaining")
        let restoredPause = PomodoroTimerViewModel(defaults: defaults)
        restoredPause.synchronizeAfterSuspension(now: end.addingTimeInterval(3600))
        precondition(restoredPause.state == .paused && restoredPause.remainingSeconds == 600)
        print("专注钟回归检查通过：长时间挂起、到期归零、暂停/恢复、旧活动解码与前台状态校准。")
    }
}
