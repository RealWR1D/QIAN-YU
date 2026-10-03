// Run with Scripts/check_api_configuration.sh. Uses isolated defaults and an in-memory key store.
import Foundation
import Security

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

final class StreamingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "stream-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let length = stream.read(&buffer, maxLength: buffer.count)
                guard length > 0 else { break }
                data.append(contentsOf: buffer.prefix(length))
            }
        }
        let payload = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(payload["stream"] as? Bool == true)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-secret")
        let model = payload["model"] as! String
        let reasoning = "data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"思考中\"}}]}"
        let content = "data: {\"choices\":[{\"delta\":{\"content\":\"你好 OK\"}}]}"
        let finish = "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}"
        var body: String
        var status = 200
        var contentType = "text/event-stream; charset=utf-8"
        switch model {
        case "crlf": body = "\u{FEFF}: heartbeat\r\n\r\nevent: message\r\n\(reasoning)\r\n\r\n\(content)\r\n\r\n\(finish)\r\n\r\ndata: [DONE]\r\n\r\n"
        case "cr": body = "\(reasoning)\r\r\(content)\r\rdata: [DONE]\r\r"
        case "multiline": body = "data: {\"choices\": [\ndata: {\"delta\": {\"content\": \"你好 OK\"}}]}\n\ndata: [DONE]\n\n"
        case "no-final-newline": body = "\(content)\n\ndata: [DONE]"
        case "finish-only": body = "\(content)\n\n\(finish)\n\n"
        case "interrupted": body = "\(content)\n\n"
        case "empty": body = "\(reasoning)\n\ndata: [DONE]\n\n"
        case "denied": status = 401; contentType = "application/json"; body = "{\"error\":{\"message\":\"Invalid fixture-secret\"}}"
        case "server-error": body = "data: {\"error\": {\"message\": \"Invalid fixture-secret\"}}\n\n"
        case "json": contentType = "application/json"; body = "{\"choices\":[{\"message\":{\"content\":\"你好 OK\"}}]}"
        default: body = "\(reasoning)\n\n\(content)\n\n\(finish)\n\ndata: {\"choices\":[],\"usage\":{}}\n\ndata: [DONE]\n\n"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Force UTF-8 characters and SSE delimiters to cross transport chunk boundaries.
        for byte in body.utf8 { client?.urlProtocol(self, didLoad: Data([byte])) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class DailyPushURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let length = stream.read(&buffer, maxLength: buffer.count)
                guard length > 0 else { break }
                data.append(contentsOf: buffer.prefix(length))
            }
        }
        let payload = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(payload["stream"] as? Bool == false)
        precondition(request.timeoutInterval == 25)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-secret")
        let model = payload["model"] as! String
        let status = model == "denied" ? 401 : 200
        let body: [String: Any] = model == "denied"
            ? ["error": ["message": "invalid fixture-secret"]]
            : ["choices": [["message": ["content": model == "empty" ? "" : "生成的推送正文"]]]]
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: body))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct RegressionChecks {
    @MainActor static func main() async throws {
        let suite = "qianyu.api.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MemoryKeyStore()
        store.values["chat-api-key"] = "legacy-secret"
        let first = AppSettings(defaults: defaults, keyStore: store)
        precondition(first.afternoonHour == 13 && first.afternoonMinute == 45, "New afternoon default")
        precondition(first.duskEnabled && first.duskHour == 18 && first.duskMinute == 0, "Independent dusk default")
        precondition(first.weatherCity == "深圳市南山区" && !first.weatherUseLocation, "Weather is manual until permission requested")
        let fullPersona = EditorialCopy.text("persona.base")
        precondition(fullPersona.count > 8_000, "Default persona must retain the full source")
        for heading in ["# 身份", "# 说话的样子", "# 你说过的话", "# 事实边界", "# 互动习惯", "# 世界：你的知识边界", "# 人物"] {
            precondition(fullPersona.contains(heading), "Missing original persona section: \(heading)")
        }
        precondition(!fullPersona.contains("get_weather"), "Do not advertise an unavailable weather tool")
        precondition(first.effectivePersonaPrompt == fullPersona)
        let fullPrompt = PersonaEngine(settings: first).buildSystemPrompt(
            userName: "测试同伴", upcomingCourseHint: "测试课 10:00 A101", weatherHint: "测试天气"
        )
        precondition(fullPrompt.hasPrefix(fullPersona), "Persona must not be summarized or truncated")
        let factualContext = String(fullPrompt.dropFirst(fullPersona.count))
        precondition(factualContext.contains("当前本地时间："))
        precondition(factualContext.contains("测试同伴") && factualContext.contains("测试课 10:00 A101"))
        precondition(factualContext.contains("测试天气"))
        for unwanted in ["提醒", "催促", "包子", "不许熬夜"] {
            precondition(!factualContext.contains(unwanted), "Context must not impose character behavior")
        }
        let personaRequest = try LLMRequestBuilder.chatRequest(
            baseURL: "https://example.org/v1", apiKey: "test", model: "test-model",
            messages: [ChatRequestMessage(role: "system", content: fullPrompt)], stream: true
        )
        let personaBody = try JSONSerialization.jsonObject(with: personaRequest.httpBody!) as! [String: Any]
        let serializedMessages = personaBody["messages"] as! [[String: Any]]
        precondition(serializedMessages[0]["content"] as? String == fullPrompt, "API must receive the complete persona")
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
        second.customPersonaPrompt = ""
        precondition(second.effectivePersonaPrompt == fullPersona, "Restore default must restore the full persona")
        second.customPersonaPrompt = "自定义角色，只讲事实"
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
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DailyPushURLProtocol.self]
        let generator = LLMService(session: URLSession(configuration: configuration))
        let generated = try await generator.completeDailyPush(baseURL: "https://fixture.invalid/v1", apiKey: "fixture-secret",
            model: "normal", thinkingEffort: "auto", messages: [.init(role: "user", content: "测试推送")])
        precondition(generated == "生成的推送正文")
        do {
            _ = try await generator.completeDailyPush(baseURL: "https://fixture.invalid/v1", apiKey: "fixture-secret",
                model: "empty", thinkingEffort: "auto", messages: [])
            preconditionFailure("empty response must fail")
        } catch LLMServiceError.emptyResponse { }
        do {
            _ = try await generator.completeDailyPush(baseURL: "https://fixture.invalid/v1", apiKey: "fixture-secret",
                model: "denied", thinkingEffort: "auto", messages: [])
            preconditionFailure("denied response must fail")
        } catch { precondition(!error.localizedDescription.contains("fixture-secret"), "Errors must redact keys") }
        let streamConfiguration = URLSessionConfiguration.ephemeral
        streamConfiguration.protocolClasses = [StreamingURLProtocol.self]
        let streamingService = LLMService(session: URLSession(configuration: streamConfiguration))
        for model in ["lf", "crlf", "cr", "multiline", "no-final-newline", "finish-only", "json"] {
            try await streamingService.validateConfiguration(baseURL: "https://stream-fixture.invalid/v1", apiKey: "fixture-secret", model: model, thinkingEffort: "auto")
            var text = ""
            var reasoning = ""
            for try await chunk in await streamingService.streamChat(baseURL: "https://stream-fixture.invalid/v1", apiKey: "fixture-secret", model: model, messages: [.init(role: "user", content: "测试")]) {
                switch chunk {
                case .content(let value): text += value
                case .reasoning(let value): reasoning += value
                }
            }
            precondition(text == "你好 OK", "Streaming content must preserve UTF-8 and event boundaries")
            if ["lf", "crlf", "cr"].contains(model) { precondition(reasoning == "思考中") }
        }
        for model in ["interrupted", "empty", "denied", "server-error"] {
            do {
                try await streamingService.validateConfiguration(baseURL: "https://stream-fixture.invalid/v1", apiKey: "fixture-secret", model: model, thinkingEffort: "auto")
                preconditionFailure("Invalid streaming response must fail: \(model)")
            } catch {
                precondition(!error.localizedDescription.contains("fixture-secret"))
                if model == "interrupted" { guard case LLMServiceError.interruptedStream = error else { throw error } }
                if model == "empty" { guard case LLMServiceError.emptyResponse = error else { throw error } }
                if model == "denied" { guard case LLMServiceError.http(statusCode: 401, responseBody: _) = error else { throw error } }
            }
        }
        let liveValidator = SettingsViewModel(settings: second, defaults: defaults, checkNotificationPermissions: false,
            connectionValidator: { _, key, _, effort in
                try await streamingService.validateConfiguration(baseURL: "https://stream-fixture.invalid/v1", apiKey: key, model: "lf", thinkingEffort: effort)
            })
        second.apiKey = "fixture-secret"
        await liveValidator.testConnection()
        precondition(liveValidator.configurationStatus == .verified, "Real streamed response must verify the settings UI")
        print("API settings, SSE validation/chat, and complete persona regression checks passed")
    }
}
