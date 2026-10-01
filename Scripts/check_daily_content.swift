import Foundation

// 本测试仅使用隔离偏好设置、假天气与假模型，不读取用户密钥或访问网络。
@MainActor final class AppSettings {
    static let shared = AppSettings()
    var aiDailyPushEnabled = true
    var isAPIConfigured = true
    var apiBaseURL = "https://fixture.invalid/v1"
    var apiKey = "fixture"
    var modelName = "fixture"
    var thinkingEffort = "auto"
    var effectivePersonaPrompt = "测试人设"
    var userName = "测试同伴"
    var weatherCity = "测试市"
    var weatherUseLocation = false
    var configurationRevision = 0
    var semesterStartDate = Date()
}
@MainActor final class DailyWeatherService {
    static let shared = DailyWeatherService()
    var cachedForecast: [String: String] = [:]
    func forecast() async -> [String: String] { cachedForecast }
}
enum LLMThinkingCapabilities {
    struct Choice { let id: String }
    struct Configuration { let options: [Choice] }
    static func configuration(baseURL: String, model: String) -> Configuration { .init(options: [.init(id: "auto")]) }
}
enum LLMServiceError: Error { case emptyResponse }
struct ChatRequestMessage {
    let role: String
    let content: String
}
actor LLMService {
    static let shared = LLMService()
    var response = "[]"
    var calls = 0
    var delay = false
    func configure(_ text: String, delay: Bool = false) { response = text; self.delay = delay }
    func count() -> Int { calls }
    func completeDailyPush(baseURL: String, apiKey: String, model: String, thinkingEffort: String,
                           messages: [ChatRequestMessage]) async throws -> String {
        calls += 1
        if delay { try await Task.sleep(for: .milliseconds(100)) }
        return response
    }
}

@main enum ContentChecks {
    @MainActor static func main() async throws {
        let suite = "qianyu.content.check.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var count = 0
        func check(_ value: Bool, _ name: String) { precondition(value, name); count += 1 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let day = calendar.startOfDay(for: Date().addingTimeInterval(86400))
        func date(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        let weekday = (calendar.component(.weekday, from: day) + 5) % 7 + 1
        let monday = calendar.dateInterval(of: .weekOfYear, for: day)!.start
        AppSettings.shared.semesterStartDate = monday
        let courses: [DailyPushPlanner.Course] = [
            .init(weekday: weekday, startMinutes: 480, endMinutes: 600, weeks: [1]),
            .init(weekday: weekday, startMinutes: 540, endMinutes: 660, weeks: [1]),
            .init(weekday: weekday, startMinutes: 1110, endMinutes: 1200, weeks: [1]),
            .init(weekday: weekday, startMinutes: 1200, endMinutes: 1250, weeks: [1])]
        let facts = DailyPushFacts.make(for: date(18), courses: courses, semesterStart: monday, calendar: calendar)
        check(facts.courseCount == 4 && facts.totalMinutes == 320, "duration excludes gaps and overlap")
        check(facts.remainingCount == 2 && facts.remainingMinutes == 140, "two remaining classes at dusk")
        let ongoing = DailyPushFacts.make(for: date(19), courses: courses, semesterStart: monday, calendar: calendar)
        check(ongoing.remainingCount == 2 && ongoing.remainingMinutes == 110, "ongoing course counts remaining time only")
        let ended = DailyPushFacts.make(for: date(22), courses: courses, semesterStart: monday, calendar: calendar)
        check(ended.remainingCount == 0 && ended.lastEnd == 1250, "courses finished by notification time")
        let inactive = DailyPushFacts.make(for: date(18), courses: courses, semesterStart: day.addingTimeInterval(14 * 86400), calendar: calendar)
        check(inactive.courseCount == 0, "before semester ignores classes")
        check(DailyPushFacts.duration([(600, 500), (1, 2)]) == 1, "invalid intervals ignored")

        let store = DailyPushContentStore(defaults: defaults)
        let entry = DailyPushPlanner.Entry(kind: .lunch, date: date(12), identifier: "fixture-lunch")
        let first = store.fallback(entry: entry, fingerprint: "same", facts: facts, userName: "同伴")
        check(first == store.fallback(entry: entry, fingerprint: "same", facts: facts, userName: "同伴"), "same pending message is cached")
        check(first == DailyPushContentStore(defaults: defaults).fallback(entry: entry, fingerprint: "same", facts: facts, userName: "同伴"), "cache persists across launch")
        var bodies = Set<String>()
        for i in 0..<160 {
            let candidate = DailyPushPlanner.Entry(kind: .lunch, date: date(12), identifier: "unique-\(i)")
            let body = store.fallback(entry: candidate, fingerprint: "fp", facts: facts, userName: "同伴").body
            check(bodies.insert(DailyPushContentStore.normalized(body)).inserted, "offline messages don't repeat")
        }
        check(!store.accept(.init(title: first.title, body: first.body), id: "repeat", fingerprint: "fp", date: day, isAI: true), "AI repeating fallback rejected")
        let message = DailyPushMessage(title: "吃好午饭呀", body: "今天课程安排紧凑，先吃好午饭，剩下的咱们一节节来。")
        check(store.accept(message, id: "new", fingerprint: "fp", date: day, isAI: true), "valid AI accepted")
        check(!store.accept(.init(title: message.title, body: message.body.replacingOccurrences(of: "，", with: "！")), id: "repeat", fingerprint: "fp", date: day, isAI: true), "punctuation-only variation rejected")
        check(!store.accept(.init(title: message.title, body: message.body + "🧋"), id: "emoji", fingerprint: "fp", date: day, isAI: true), "emoji-only variation rejected")
        check(!store.accept(.init(title: "标题", body: "正文\n第二行"), id: "line", fingerprint: "fp", date: day, isAI: true), "multiline notification rejected")
        check(!store.accept(.init(title: "标题", body: String(repeating: "好", count: 121)), id: "long", fingerprint: "fp", date: day, isAI: true), "oversized output rejected")
        check(store.record(id: "new", fingerprint: "changed") == nil, "course/weather changes invalidate cache")
        let fenced = "```json\n[{\"id\":\"a\",\"title\":\"标题\",\"body\":\"有效的短句正文\"}]\n```"
        check(try DailyPushContentService.decode(fenced).first?.id == "a", "markdown fences parsed")
        do { _ = try DailyPushContentService.decode("不是 JSON"); preconditionFailure("bad JSON should fail") }
        catch { count += 1 }
        let serviceStore = DailyPushContentStore(defaults: defaults)
        let service = DailyPushContentService(store: serviceStore)
        let planned = DailyPushPlanner.Entry(kind: .dusk, date: date(18), identifier: "service-dusk")
        service.setPlan(entries: [planned], courses: courses)
        let offline = service.message(for: planned)
        let reply = "[{\"id\":\"service-dusk\",\"title\":\"傍晚歇口气呀\",\"body\":\"还有两门课排在后面，先吃点东西，再踏实走完剩下的安排吧。\"}]"
        await LLMService.shared.configure(reply)
        var updates = 0
        service.refresh { updates += $0.count }
        await service.waitForRefresh()
        check(updates == 1 && service.message(for: planned) != offline, "AI replaces one pending cached body")
        let requests = await LLMService.shared.count()
        service.refresh { _ in preconditionFailure("unchanged cache must not refresh") }
        await service.waitForRefresh()
        check(await LLMService.shared.count() == requests, "unchanged scheduling avoids repeated model calls")
        AppSettings.shared.aiDailyPushEnabled = false
        service.setPlan(entries: [planned], courses: courses)
        check(service.message(for: planned).body != "还有两门课排在后面，先吃点东西，再踏实走完剩下的安排吧。", "turning off AI returns to offline copy")
        AppSettings.shared.aiDailyPushEnabled = true
        let changed = DailyPushPlanner.Entry(kind: .afternoon, date: date(13, 45), identifier: "changed-plan")
        service.setPlan(entries: [changed], courses: courses)
        await LLMService.shared.configure("[]", delay: true)
        service.refresh { _ in preconditionFailure("cancelled plan cannot replace new notifications") }
        await Task.yield()
        service.setPlan(entries: [planned], courses: [])
        try await Task.sleep(for: .milliseconds(150))
        await service.waitForRefresh()
        check(!service.message(for: planned).body.contains("还有两门"), "new plan doesn't inherit stale AI body")
        let batched = (0..<9).map {
            DailyPushPlanner.Entry(kind: .afternoon, date: date(13, 45), identifier: "batch-\($0)")
        }
        service.setPlan(entries: batched, courses: courses)
        await LLMService.shared.configure("[]")
        let beforeBatch = await LLMService.shared.count()
        service.refresh { _ in preconditionFailure("empty batch cannot update notifications") }
        await service.waitForRefresh()
        check(await LLMService.shared.count() == beforeBatch + 2, "at most eight messages per model request")
        let failureEntry = DailyPushPlanner.Entry(kind: .morning, date: date(8), identifier: "invalid-json")
        service.setPlan(entries: [failureEntry], courses: [])
        let failureFallback = service.message(for: failureEntry)
        await LLMService.shared.configure("这不是 JSON")
        service.refresh { _ in preconditionFailure("bad JSON must keep local notification") }
        await service.waitForRefresh()
        check(service.message(for: failureEntry) == failureFallback, "bad JSON retains already prepared fallback")
        print("Daily content checks passed: \(count)")
    }
}
