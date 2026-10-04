//
//  LLMService.swift
//  QIAN YU
//

import Foundation

public enum OpenAICompatibleEndpoint {
    /// Accept a service root, versioned API root, /models, or a complete chat endpoint.
    public static func chatCompletionsURL(from baseURL: String) throws -> URL {
        try endpointURL(from: baseURL, resource: "chat/completions")
    }

    public static func modelsURL(from baseURL: String) throws -> URL {
        try endpointURL(from: baseURL, resource: "models")
    }

    private static func endpointURL(from baseURL: String, resource: String) throws -> URL {
        let cleaned = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: cleaned),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else {
            throw LLMServiceError.invalidConfiguration(String(localized: "API 地址须为完整的 http:// 或 https:// 地址，且不能包含用户名或密码。"))
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/chat/completions", "/models"] where path.hasSuffix(suffix) {
            path.removeLast(suffix.count)
            break
        }
        if path.isEmpty && (["api.openai.com", "api.xiaomimimo.com", "api.siliconflow.cn", "api.siliconflow.com", "ollama.com"].contains(host.lowercased()) || components.port == 11434) {
            path = "/v1"
        }
        components.path = path + "/" + resource
        components.fragment = nil
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}

public struct ThinkingChoice: Identifiable, Sendable {
    public let id: String
    public let displayName: String
}

public struct ThinkingConfiguration: Sendable {
    public let options: [ThinkingChoice]
    public let explanation: String
    fileprivate let mapping: ThinkingParameterMapping

    /// A saved choice from another provider must never leak unsupported request parameters.
    public func effectiveValue(for value: String) -> String {
        options.contains { $0.id == value } ? value : "auto"
    }

    fileprivate func parameters(for value: String) -> [String: Any] {
        let effort = effectiveValue(for: value)
        guard effort != "auto" else { return [:] }
        switch mapping {
        case .none: return [:]
        case .reasoningEffort: return ["reasoning_effort": effort]
        case .thinkingToggle: return ["thinking": ["type": effort == "none" ? "disabled" : "enabled"]]
        case .deepseek:
            if effort == "none" { return ["thinking": ["type": "disabled"]] }
            return ["thinking": ["type": "enabled"], "reasoning_effort": effort]
        case .siliconToggle: return ["enable_thinking": effort != "none"]
        case .siliconEffort:
            if effort == "none" { return ["enable_thinking": false] }
            return ["enable_thinking": true, "reasoning_effort": effort]
        }
    }
}

fileprivate enum ThinkingParameterMapping: Sendable {
    case none, reasoningEffort, thinkingToggle, deepseek, siliconToggle, siliconEffort
}

public enum LLMThinkingCapabilities {
    // Provider contracts checked against official API docs. Unknown models keep server defaults.
    // Sources and regression cases are recorded in Scripts/API_CONFIGURATION.md.
    public static func configuration(baseURL: String, model: String) -> ThinkingConfiguration {
        let url = try? OpenAICompatibleEndpoint.chatCompletionsURL(from: baseURL)
        let host = url?.host?.lowercased() ?? ""
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host == "api.deepseek.com" {
            if ["deepseek-flash", "deepseek-v4-flash", "deepseek-v4-pro"].contains(model) {
                return configuration(["none", "low", "high", "max"], .deepseek,
                    String(localized: "关闭发送 thinking.type=disabled；其余档位发送 thinking.type=enabled 和同名 reasoning_effort（low / high / max）。自动使用服务端默认值。"))
            }
            if ["deepseek-chat", "deepseek-reasoner"].contains(model) {
                return configuration([], .none, String(localized: "这是 DeepSeek 的旧模型名称。请刷新模型列表并选择当前可用模型；旧名称的思考模式由模型本身决定。"))
            }
        }
        if host == "api.xiaomimimo.com", ["mimo-v2.5", "mimo-v2.5-pro"].contains(model) {
            return configuration(["none", "enabled"], .thinkingToggle,
                String(localized: "MiMo 使用 thinking.type=enabled / disabled 控制思考开关，不使用 low / medium / high。自动不传此参数。"))
        }
        if ["api.siliconflow.cn", "api.siliconflow.com"].contains(host) {
            if ["pro/deepseek-ai/deepseek-v4", "deepseek-ai/deepseek-v4-flash", "pro/zai-org/glm-5.2"].contains(model) {
                return configuration(["none", "high", "max"], .siliconEffort,
                    String(localized: "硅基流动：关闭发送 enable_thinking=false；开启发送 enable_thinking=true 及 reasoning_effort=high / max。自动使用服务端默认值。"))
            }
            // Only expose a toggle for known hybrid models, not R1 / Thinking-only models.
            if model.contains("deepseek-v3.2") || (model.contains("qwen3-") && !model.contains("thinking") && !model.contains("instruct") && !model.contains("coder")) {
                return configuration(["none", "enabled"], .siliconToggle,
                    String(localized: "此模型使用 enable_thinking=true / false 切换思考。thinking_budget 是 token 上限，不等同于 reasoning_effort，应用不虚构低、中、高映射。"))
            }
        }
        if host == "api.openai.com" {
            if model.hasPrefix("gpt-6-astra") {
                return openAI(["low", "medium", "high", "xhigh", "max"])
            }
            if model.hasPrefix("gpt-6-sol") || model.hasPrefix("gpt-6-luna") || model.hasPrefix("gpt-5.6") {
                return openAI(["none", "low", "medium", "high", "xhigh", "max"])
            }
            if model.contains("chat") || model.contains("codex") || model.contains("pro") || model.contains("deep-research") {
                return configuration([], .none, String(localized: "此专用模型的参数和接口可能不同，当前使用服务端默认思考设置；请用连接测试确认它支持聊天接口。"))
            }
            if model == "gpt-5.1" || model.hasPrefix("gpt-5.1-20") { return openAI(["none", "low", "medium", "high"]) }
            if ["gpt-5.2", "gpt-5.4", "gpt-5.5"].contains(where: { model == $0 || model.hasPrefix($0 + "-") }) {
                return openAI(["none", "low", "medium", "high", "xhigh"])
            }
            if model == "gpt-5" || model.hasPrefix("gpt-5-20") || model.hasPrefix("gpt-5-mini") || model.hasPrefix("gpt-5-nano") {
                return openAI(["minimal", "low", "medium", "high"])
            }
            if model == "o1" || model.hasPrefix("o1-20") || model == "o3" || model.hasPrefix("o3-") || model.hasPrefix("o4-mini") {
                return openAI(["low", "medium", "high"])
            }
        }
        if (url?.port == 11434 || host == "ollama.com"), model.hasPrefix("gpt-oss") {
            return configuration(["low", "medium", "high"], .reasoningEffort,
                String(localized: "Ollama 的 GPT-OSS 使用 reasoning_effort=low / medium / high，不支持关闭思考。自动使用本地模型默认值。"))
        }
        return configuration([], .none, String(localized: "尚未确认此地址与模型的思考参数支持情况，使用服务端默认设置，不发送 reasoning_effort 或其他思考参数。自动不表示关闭思考。"))
    }

    private static func openAI(_ efforts: [String]) -> ThinkingConfiguration {
        configuration(efforts, .reasoningEffort,
            String(localized: "各档位直接对应 OpenAI 的同名 reasoning_effort；自动省略该字段并使用模型默认值。仅显示当前模型支持的档位，不支持关闭时不显示“关闭”。"))
    }

    private static func configuration(_ efforts: [String], _ mapping: ThinkingParameterMapping, _ explanation: String) -> ThinkingConfiguration {
        ThinkingConfiguration(options: (["auto"] + efforts).map { value in
            let label: String
            switch value {
            case "auto": label = String(localized: "自动（模型默认）")
            case "none": label = String(localized: "关闭思考")
            case "enabled": label = String(localized: "开启思考")
            case "minimal": label = String(localized: "最少 · minimal")
            case "low": label = String(localized: "低 · low")
            case "medium": label = String(localized: "中 · medium")
            case "high": label = String(localized: "高 · high")
            case "xhigh": label = String(localized: "更高 · xhigh")
            default: label = String(localized: "最高 · max")
            }
            return ThinkingChoice(id: value, displayName: label)
        }, explanation: explanation, mapping: mapping)
    }
}

public enum LLMServiceError: LocalizedError, Sendable {
    case http(statusCode: Int, responseBody: String)
    case invalidConfiguration(String)
    case invalidResponse(String)
    case server(String)
    case emptyResponse
    case interruptedStream

    public var errorDescription: String? {
        switch self {
        case .http(let statusCode, let responseBody):
            let detail = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? String(localized: "模型服务返回 HTTP \(statusCode)。")
                : String(localized: "模型服务返回 HTTP \(statusCode)：\(detail)")
        case .invalidConfiguration(let detail), .invalidResponse(let detail), .server(let detail): return detail
        case .emptyResponse: return String(localized: "模型未返回可用的文字回复，请检查所选模型是否支持聊天。")
        case .interruptedStream: return String(localized: "模型的回复流提前中断，请重试。")
        }
    }
}

public struct ChatRequestMessage: Codable, Sendable {
    public let role: String
    public let content: String
    public init(role: String, content: String) { self.role = role; self.content = content }
}

public enum StreamChunk: Sendable {
    case reasoning(String)
    case content(String)
}

/// Shared by normal chat and explicit configuration validation.
public enum LLMRequestBuilder {
    public static func chatRequest(baseURL: String, apiKey: String, model: String, thinkingEffort: String = "auto", messages: [ChatRequestMessage], stream: Bool) throws -> URLRequest {
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw LLMServiceError.invalidConfiguration(String(localized: "请先填写或选择模型 ID。")) }
        var request = authorizedRequest(url: try OpenAICompatibleEndpoint.chatCompletionsURL(from: baseURL), apiKey: apiKey)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        var payload: [String: Any] = ["model": model, "messages": messages.map { ["role": $0.role, "content": $0.content] }, "stream": stream]
        let thinking = LLMThinkingCapabilities.configuration(baseURL: baseURL, model: model)
        payload.merge(thinking.parameters(for: thinkingEffort)) { _, new in new }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    fileprivate static func authorizedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        return request
    }
}

public actor LLMService {
    public static let shared = LLMService()
    private let session: URLSession

    /// Session injection keeps regression tests offline, without reading user credentials.
    public init(session: URLSession = .shared) { self.session = session }

    public func fetchModels(baseURL: String, apiKey: String) async throws -> [String] {
        let firstURL = try OpenAICompatibleEndpoint.modelsURL(from: baseURL)
        var nextURL: URL? = firstURL
        var visited = Set<URL>()
        var models = Set<String>()
        while let url = nextURL {
            try Task.checkCancellation()
            guard visited.insert(url).inserted, visited.count <= 100 else {
                throw LLMServiceError.invalidResponse(String(localized: "模型列表分页异常，请稍后重试。"))
            }
            let request = LLMRequestBuilder.authorizedRequest(url: url, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            try checkHTTP(response, body: data, apiKey: apiKey)
            let json = try jsonObject(data, apiKey: apiKey)
            guard let entries = json["data"] as? [[String: Any]] else {
                throw LLMServiceError.invalidResponse(String(localized: "服务未返回兼容的模型列表；仍可手动填写模型 ID 并测试连接。"))
            }
            for entry in entries {
                if let id = entry["id"] as? String, !id.isEmpty { models.insert(id) }
            }
            nextURL = try paginationURL(json: json, currentURL: url, firstURL: firstURL, entries: entries)
        }
        return models.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// 日常推送批量生成：有独立超时，不占用聊天历史。
    public func completeDailyPush(baseURL: String, apiKey: String, model: String,
                                  thinkingEffort: String, messages: [ChatRequestMessage]) async throws -> String {
        var request = try LLMRequestBuilder.chatRequest(baseURL: baseURL, apiKey: apiKey, model: model,
            thinkingEffort: thinkingEffort, messages: messages, stream: false)
        request.timeoutInterval = 25
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        try checkHTTP(response, body: data, apiKey: apiKey)
        guard data.count <= 1_048_576 else { throw LLMServiceError.invalidResponse("推送文案响应过长") }
        let json = try jsonObject(data, apiKey: apiKey)
        guard let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String, !content.isEmpty else { throw LLMServiceError.emptyResponse }
        return content
    }

    public func validateConfiguration(baseURL: String, apiKey: String, model: String, thinkingEffort: String) async throws {
        // Exercise the actual streaming path, selected model, and reasoning settings.
        // Listing models alone does not establish permission, credit, or chat support.
        let stream = streamChat(baseURL: baseURL, apiKey: apiKey, model: model, thinkingEffort: thinkingEffort,
                                messages: [ChatRequestMessage(role: "user", content: "Reply with only OK.")])
        for try await _ in stream { try Task.checkCancellation() }
    }

    public func streamChat(baseURL: String, apiKey: String, model: String, thinkingEffort: String = "auto", messages: [ChatRequestMessage]) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try LLMRequestBuilder.chatRequest(baseURL: baseURL, apiKey: apiKey, model: model, thinkingEffort: thinkingEffort, messages: messages, stream: true)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        var body = Data()
                        for try await byte in bytes {
                            body.append(byte)
                            if body.count >= 8_192 { break }
                        }
                        try checkHTTP(http, body: body, apiKey: apiKey)
                        return
                    }
                    // Some compatible services ignore stream=true and return a complete JSON response.
                    if http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("application/json") == true {
                        var body = Data()
                        for try await byte in bytes {
                            body.append(byte)
                            guard body.count <= 4_194_304 else { throw LLMServiceError.invalidResponse(String(localized: "模型回复超过可处理的大小。")) }
                        }
                        let json = try jsonObject(body, apiKey: apiKey)
                        guard let choices = json["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any],
                              let content = message["content"] as? String, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            throw LLMServiceError.emptyResponse
                        }
                        if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty { continuation.yield(.reasoning(reasoning)) }
                        continuation.yield(.content(content))
                        continuation.finish()
                        return
                    }
                    var decoder = ChatEventDecoder(apiKey: apiKey)
                    // AsyncBytes.lines drops empty lines, including SSE event boundaries.
                    // Frame bytes ourselves so distinct JSON events are never concatenated.
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        for chunk in try decoder.consume(byte: byte) { continuation.yield(chunk) }
                        if decoder.isDone { break }
                    }
                    for chunk in try decoder.finish() { continuation.yield(chunk) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}

private func checkHTTP(_ response: URLResponse, body: Data, apiKey: String) throws {
    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    guard (200...299).contains(http.statusCode) else {
        throw LLMServiceError.http(statusCode: http.statusCode, responseBody: responseDetail(body, apiKey: apiKey))
    }
}

private func responseDetail(_ data: Data, apiKey: String) -> String {
    let raw: String
    if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = object["error"] as? [String: Any], let message = error["message"] as? String {
        raw = message
    } else { raw = String(data: data, encoding: .utf8) ?? "" }
    var redacted = raw
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    if !key.isEmpty { redacted = redacted.replacingOccurrences(of: key, with: "[已隐藏]") }
    for pattern in ["(?i)Bearer\\s+[^\\s\\\"<>]+", "(?i)\\b(?:sk|tp|ttp)-[A-Za-z0-9_-]+"] {
        redacted = redacted.replacingOccurrences(of: pattern, with: "[已隐藏]", options: .regularExpression)
    }
    return String(redacted.prefix(1_200))
}

private func jsonObject(_ data: Data, apiKey: String) throws -> [String: Any] {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw LLMServiceError.invalidResponse(String(localized: "服务返回的内容不是有效的聊天 API JSON，请检查 API 地址。"))
    }
    if object["error"] != nil, !(object["error"] is NSNull) {
        throw LLMServiceError.server(responseDetail(data, apiKey: apiKey))
    }
    return object
}

private func paginationURL(json: [String: Any], currentURL: URL, firstURL: URL, entries: [[String: Any]]) throws -> URL? {
    if let next = json["next"] as? String, !next.isEmpty {
        guard let url = URL(string: next, relativeTo: currentURL)?.absoluteURL,
              url.scheme == firstURL.scheme, url.host == firstURL.host, url.port == firstURL.port,
              url.user == nil, url.password == nil else {
            throw LLMServiceError.invalidResponse(String(localized: "模型列表返回了无效的分页地址。"))
        }
        return url
    }
    let cursor = json["next_cursor"] as? String
    guard json["has_more"] as? Bool == true || (cursor?.isEmpty == false) else { return nil }
    guard let value = cursor ?? (json["last_id"] as? String) ?? (entries.last?["id"] as? String), !value.isEmpty,
          var components = URLComponents(url: currentURL, resolvingAgainstBaseURL: false) else {
        throw LLMServiceError.invalidResponse(String(localized: "模型列表缺少下一页信息。"))
    }
    let parameter = cursor == nil ? "after" : "cursor"
    var items = components.queryItems ?? []
    items.removeAll { $0.name == parameter }
    items.append(URLQueryItem(name: parameter, value: value))
    components.queryItems = items
    return components.url
}

/// SSE framing supports data: with/without a space and multi-line event data.
private struct ChatEventDecoder {
    let apiKey: String
    private var lineBytes: [UInt8] = []
    private var skipLF = false
    private var isFirstLine = true
    private var dataLines: [String] = []
    private var receivedContent = false
    private var receivedFinish = false
    private(set) var isDone = false

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// SSE accepts LF, CRLF, and CR. Decode UTF-8 only after a whole line arrives.
    mutating func consume(byte: UInt8) throws -> [StreamChunk] {
        if skipLF {
            skipLF = false
            if byte == 10 { return [] }
        }
        if byte == 10 || byte == 13 {
            skipLF = byte == 13
            return try consumeBufferedLine()
        }
        lineBytes.append(byte)
        guard lineBytes.count <= 1_048_576 else {
            throw LLMServiceError.invalidResponse(String(localized: "模型回复超过可处理的大小。"))
        }
        return []
    }

    private mutating func consumeBufferedLine() throws -> [StreamChunk] {
        if isFirstLine {
            isFirstLine = false
            if lineBytes.starts(with: [0xEF, 0xBB, 0xBF]) { lineBytes.removeFirst(3) }
        }
        guard let line = String(bytes: lineBytes, encoding: .utf8) else {
            throw LLMServiceError.invalidResponse(String(localized: "服务返回的内容不是有效的聊天 API JSON，请检查 API 地址。"))
        }
        lineBytes.removeAll(keepingCapacity: true)
        return try consume(line)
    }

    mutating func consume(_ line: String) throws -> [StreamChunk] {
        if line.isEmpty { return try dispatch() }
        if line.hasPrefix(":") || line.hasPrefix("event:") || line.hasPrefix("id:") || line.hasPrefix("retry:") { return [] }
        guard line.hasPrefix("data:") else {
            throw LLMServiceError.invalidResponse(String(localized: "服务返回了非 SSE 聊天内容，请检查 API 地址和模型。"))
        }
        var value = String(line.dropFirst(5))
        if value.hasPrefix(" ") { value.removeFirst() }
        dataLines.append(value)
        return []
    }

    mutating func finish() throws -> [StreamChunk] {
        var chunks: [StreamChunk] = []
        if !lineBytes.isEmpty { chunks += try consumeBufferedLine() }
        chunks += try dispatch()
        guard receivedContent else { throw LLMServiceError.emptyResponse }
        guard isDone || receivedFinish else { throw LLMServiceError.interruptedStream }
        return chunks
    }

    private mutating func dispatch() throws -> [StreamChunk] {
        guard !dataLines.isEmpty else { return [] }
        let data = dataLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        dataLines.removeAll(keepingCapacity: true)
        if data == "[DONE]" { isDone = true; return [] }
        let object = try jsonObject(Data(data.utf8), apiKey: apiKey)
        guard let choices = object["choices"] as? [[String: Any]] else {
            throw LLMServiceError.invalidResponse(String(localized: "服务返回了无法识别的聊天数据。"))
        }
        guard let choice = choices.first else { return [] } // usage-only chunk
        if let reason = choice["finish_reason"] as? String, !reason.isEmpty { receivedFinish = true }
        guard let delta = choice["delta"] as? [String: Any] else { return [] }
        var chunks: [StreamChunk] = []
        if let reasoning = (delta["reasoning_content"] ?? delta["reasoning"]) as? String, !reasoning.isEmpty { chunks.append(.reasoning(reasoning)) }
        if let content = delta["content"] as? String, !content.isEmpty {
            receivedContent = receivedContent || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            chunks.append(.content(content))
        }
        return chunks
    }
}
