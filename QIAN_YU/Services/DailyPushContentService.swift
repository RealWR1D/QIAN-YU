import Foundation

@MainActor final class DailyPushContentService {
    private struct Item {
        let entry: DailyPushPlanner.Entry
        let facts: DailyPushFacts
        let fingerprint: String
        let context: String
    }
    private let store: DailyPushContentStore

    init(store: DailyPushContentStore? = nil) { self.store = store ?? DailyPushContentStore() }

    func waitForRefresh() async { await refreshTask?.value }
    private var items: [String: Item] = [:]
    private var courses: [DailyPushPlanner.Course] = []
    private var revision = UUID()
    private var planKey = ""
    private var refreshTask: Task<Void, Never>?
    private var lastAttempt: Date = .distantPast
    private var weatherKey = ""
    private var weather: [String: String] = [:]

    func setPlan(entries: [DailyPushPlanner.Entry], courses: [DailyPushPlanner.Course]) {
        self.courses = courses
        let settings = AppSettings.shared
        let defaults = UserDefaults.standard
        let locationKey = settings.weatherCity + "\(settings.weatherUseLocation)"
            + "\(defaults.double(forKey: "qianyu_weather_auto_stamp"))"
            + "\(defaults.double(forKey: "qianyu_weather_manual_stamp"))"
        weather = DailyWeatherService.shared.cachedForecast
        weatherKey = locationKey
        let updated = entries.map { item(for: $0) }
        let key = DailyPushContentStore.digest(updated.map(\.fingerprint).joined() + "\(AppSettings.shared.aiDailyPushEnabled)")
        if key != planKey {
            refreshTask?.cancel()
            refreshTask = nil
            revision = UUID()
            planKey = key
            lastAttempt = .distantPast
        }
        items = Dictionary(uniqueKeysWithValues: updated.map { ($0.entry.identifier, $0) })
    }

    func message(for entry: DailyPushPlanner.Entry) -> DailyPushMessage {
        let item = items[entry.identifier] ?? item(for: entry)
        return store.fallback(entry: entry, fingerprint: item.fingerprint, facts: item.facts,
                              userName: AppSettings.shared.userName)
    }

    /// 在已有本地排程之后异步补充 AI 文案。睡眠动作不会等待网络。
    func refresh(onUpdate: @escaping @MainActor ([DailyPushPlanner.Entry]) -> Void) {
        let settings = AppSettings.shared
        guard settings.aiDailyPushEnabled, settings.isAPIConfigured, refreshTask == nil,
              Date().timeIntervalSince(lastAttempt) >= 3600,
              items.values.contains(where: { store.record(id: $0.entry.identifier, fingerprint: $0.fingerprint)?.isAI != true })
                || Date().timeIntervalSince(lastAttempt) >= 3 * 3600 else { return }
        lastAttempt = Date()
        let token = revision
        // 在等待网络前快照 API 配置；完成后检查计划版本，避免旧课表覆盖新通知。
        let baseURL = settings.apiBaseURL
        let apiKey = settings.apiKey
        let model = settings.modelName
        let options = LLMThinkingCapabilities.configuration(baseURL: baseURL, model: model).options
        let thinking = options.first { $0.id == "none" }?.id ?? options.first { $0.id != "auto" }?.id ?? "auto"
        let persona = settings.effectivePersonaPrompt
        refreshTask = Task { @MainActor in
            defer { if token == self.revision { self.refreshTask = nil } }
            let forecast = await DailyWeatherService.shared.forecast()
            guard !Task.isCancelled, token == self.revision else { return }
            self.weather = forecast
            let current = self.items.values.map { self.item(for: $0.entry) }.sorted { $0.entry.date < $1.entry.date }
            self.items = Dictionary(uniqueKeysWithValues: current.map { ($0.entry.identifier, $0) })
            let needed = current.filter {
                $0.entry.date > Date() && self.store.record(id: $0.entry.identifier, fingerprint: $0.fingerprint)?.isAI != true
            }
            guard !needed.isEmpty else { return }
            do {
                // 小批次生成，避免整周正文在慢模型上超过单次请求的超时。
                for offset in stride(from: 0, to: needed.count, by: 8) {
                    guard !Task.isCancelled, token == self.revision else { return }
                    let batch = Array(needed.dropFirst(offset).prefix(8))
                    let contexts = batch.map { ["id": $0.entry.identifier, "情境": $0.context] }
                    guard let data = try? JSONSerialization.data(withJSONObject: contexts),
                          let contextText = String(data: data, encoding: .utf8) else { return }
                    let prompt = EditorialCopy.text("notification.ai.prompt", [
                        "contexts": contextText, "recent": self.store.recentBodies.joined(separator: "\n")])
                    let reply = try await LLMService.shared.completeDailyPush(baseURL: baseURL, apiKey: apiKey, model: model,
                        thinkingEffort: thinking, messages: [.init(role: "system", content: persona), .init(role: "user", content: prompt)])
                    guard !Task.isCancelled, token == self.revision else { return }
                    let decoded = try Self.decode(reply)
                    let expected = Dictionary(uniqueKeysWithValues: batch.map { ($0.entry.identifier, $0) })
                    var seen = Set<String>()
                    var updated: [DailyPushPlanner.Entry] = []
                    for row in decoded {
                        guard seen.insert(row.id).inserted, let item = expected[row.id], item.entry.date > Date() else { continue }
                        if self.store.accept(.init(title: row.title, body: row.body), id: row.id, fingerprint: item.fingerprint,
                                             date: item.entry.date, isAI: true) { updated.append(item.entry) }
                    }
                    if !updated.isEmpty { onUpdate(updated) }
                }
            } catch {
                // 网络、无效 JSON、超时均保留已安排的多样化本地通知；不记录密钥或服务端响应。
                if !Task.isCancelled { NSLog("每日 AI 文案未更新，保留本地提醒。") }
            }
        }
    }

    private func item(for entry: DailyPushPlanner.Entry) -> Item {
        let settings = AppSettings.shared
        let facts = DailyPushFacts.make(for: entry.date, courses: courses, semesterStart: settings.semesterStartDate)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: entry.date)
        let weatherHint = entry.kind == .morning ? (weather[day] ?? EditorialCopy.text("notification.context.weatherMissing")) : ""
        let courseHint = entry.kind == .evening ? EditorialCopy.text("notification.context.bedtime") : facts.summary
        let context = EditorialCopy.text("notification.context.entry", ["date": day, "kind": entry.kind.rawValue,
            "userName": String(settings.userName.prefix(24)), "course": courseHint, "weather": weatherHint])
        let fingerprint = DailyPushContentStore.digest(context + settings.effectivePersonaPrompt
            + weatherKey + settings.apiBaseURL + settings.modelName + settings.thinkingEffort
            + "\(settings.configurationRevision)\(settings.aiDailyPushEnabled)")
        return .init(entry: entry, facts: facts, fingerprint: fingerprint, context: context)
    }

    struct Row: Decodable {
        let id: String
        let title: String
        let body: String
    }
    static func decode(_ text: String) throws -> [Row] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let content: String
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            guard lines.count >= 3, lines.last == "```" else { throw LLMServiceError.emptyResponse }
            content = lines.dropFirst().dropLast().joined(separator: "\n")
        } else { content = trimmed }
        return try JSONDecoder().decode([Row].self, from: Data(content.utf8))
    }
}
