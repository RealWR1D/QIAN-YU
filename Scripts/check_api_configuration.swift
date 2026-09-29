// Run with Scripts/check_api_configuration.sh. Uses isolated defaults and an in-memory key store.
import Foundation
import Security

public enum EditorialCopy {
    public static func text(_ key: String, _ values: [String: CustomStringConvertible] = [:]) -> String {
        let template = key == "persona.base" ? "默认千语人设" : "{base} {userName} {timeContext}"
        var result = template
        for (name, value) in values { result = result.replacingOccurrences(of: "{\(name)}", with: value.description) }
        return result
    }
}
@MainActor public final class NotificationManager {
    public static let shared = NotificationManager()
    public func checkAuthorizationStatus() async -> Bool { false }
    public func requestAuthorization() async -> Bool { false }
    public func scheduleDailyNotifications() {}
    public func sendTestNotification(_ completion: @escaping (Bool) -> Void) { completion(true) }
}

final class MemoryKeyStore: APIKeyStorage {
    var values: [String: String] = [:]
    var shouldFailWrites = false
    func read(account: String, legacy: Bool) -> (value: String?, status: OSStatus) {
        if let value = values[account] { return (value, errSecSuccess) }
        return (nil, errSecItemNotFound)
    }
    func write(_ value: String, account: String) -> Bool {
        if shouldFailWrites { return false }
        if value.isEmpty { values.removeValue(forKey: account) } else { values[account] = value }
        return true
    }
}

@main struct RegressionChecks {
    @MainActor static func main() async throws {
        let suite = "qianyu.api.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MemoryKeyStore()
        store.values["chat-api-key"] = "legacy-secret"
        let first = AppSettings(defaults: defaults, keyStore: store)
        precondition(first.apiKey == "legacy-secret")
        precondition(store.values["chat-api-key.deepseek"] == "legacy-secret")
        first.modelName = "manually-entered/deepseek-model"
        first.customPersonaPrompt = "自定义角色，只讲事实"
        first.thinkingEffort = "high"
        precondition(first.activateProvider(code: "openai", defaultURL: "https://api.openai.com/v1/chat/completions", defaultModel: "gpt-5"))
        precondition(first.apiKey.isEmpty, "Switching providers must not reuse the old key")
        first.apiKey = "openai-secret"
        first.modelName = "manually-entered/openai-model"
        precondition(first.activateProvider(code: "deepseek", defaultURL: "https://api.deepseek.com/chat/completions", defaultModel: "deepseek-flash"))
        precondition(first.modelName == "manually-entered/deepseek-model")
        precondition(first.thinkingEffort == "high")
        precondition(first.apiKey == "legacy-secret")
        let second = AppSettings(defaults: defaults, keyStore: store)
        precondition(second.modelName == "manually-entered/deepseek-model")
        precondition(second.customPersonaPrompt == "自定义角色，只讲事实")
        precondition(PersonaEngine(settings: second).buildSystemPrompt().contains("自定义角色，只讲事实"))
        precondition(second.activateProvider(code: "openai", defaultURL: "", defaultModel: ""))
        precondition(second.modelName == "manually-entered/openai-model")
        precondition(second.apiKey == "openai-secret")
        store.shouldFailWrites = true
        second.apiKey = "unsaved-secret"
        precondition(second.apiKeyStorageError != nil)
        precondition(!second.activateProvider(code: "deepseek", defaultURL: "", defaultModel: ""), "Unsaved key must not be discarded")
        store.shouldFailWrites = false
        second.retryAPIKeySave()
        precondition(second.apiKeyStorageError == nil)
        precondition(second.activateProvider(code: "deepseek", defaultURL: "", defaultModel: ""))
        precondition(store.values["chat-api-key.openai"] == "unsaved-secret")

        let modelsURL = try OpenAICompatibleEndpoint.modelsURL(from: "https://api.openai.com/v1/chat/completions")
        precondition(modelsURL.absoluteString == "https://api.openai.com/v1/models")
        let request = try LLMRequestBuilder.chatRequest(
            baseURL: "https://api.openai.com/v1", apiKey: "secret", model: "gpt-5",
            thinkingEffort: "high", messages: [ChatRequestMessage(role: "user", content: "test")], stream: true
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        precondition(body["reasoning_effort"] as? String == "high")
        precondition(body["temperature"] == nil)
        let unknown = try LLMRequestBuilder.chatRequest(
            baseURL: "https://example.org/v1", apiKey: "secret", model: "new-model",
            thinkingEffort: "high", messages: [], stream: true
        )
        let unknownBody = try JSONSerialization.jsonObject(with: unknown.httpBody!) as! [String: Any]
        precondition(unknownBody["reasoning_effort"] == nil)

        let vm = SettingsViewModel(
            settings: second, defaults: defaults, checkNotificationPermissions: false,
            modelLoader: { _, _ in (0..<100).map { "model-\($0)" } },
            connectionValidator: { _, _, _, _ in }
        )
        precondition(vm.configurationStatus == .saved)
        await vm.refreshModels()
        precondition(vm.availableModels.count >= 101, "All fetched IDs and the manual model should remain selectable")
        await vm.testConnection()
        precondition(vm.configurationStatus == .verified)
        second.modelName = "another-custom-model"
        vm.configurationDidChange()
        precondition(vm.configurationStatus == .saved)
        print("API settings regression checks passed")
    }
}
