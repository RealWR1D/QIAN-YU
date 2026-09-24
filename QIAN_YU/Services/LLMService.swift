//
//  LLMService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation

public struct ChatRequestMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum StreamChunk {
    case reasoning(String)
    case content(String)
}

public actor LLMService {
    public static let shared = LLMService()

    private init() {}

    /// 发起原生流式对话请求，支持思考流 (reasoning_content) 与正文流 (content)
    public func streamChat(
        baseURL: String,
        apiKey: String,
        model: String,
        thinkingEffort: String = "none",
        messages: [ChatRequestMessage]
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var cleanURLString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanURLString.hasSuffix("/") {
                        cleanURLString = String(cleanURLString.dropLast())
                    }
                    if !cleanURLString.hasSuffix("/chat/completions") {
                        cleanURLString += "/chat/completions"
                    }
                    guard let url = URL(string: cleanURLString) else {
                        throw URLError(.badURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    request.timeoutInterval = 60

                    var payload: [String: Any] = [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]

                    // 思考强度 (Thinking Effort) 参数装配
                    switch thinkingEffort {
                    case "low", "medium", "high":
                        payload["reasoning_effort"] = thinkingEffort
                    case "none":
                        payload["temperature"] = 0.75
                    default:
                        payload["temperature"] = 0.75
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        throw URLError(.badServerResponse)
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed.hasPrefix(":") { continue }

                        if trimmed == "data: [DONE]" {
                            continuation.finish()
                            return
                        }

                        if trimmed.hasPrefix("data: ") {
                            let jsonString = String(trimmed.dropFirst(6))
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any] {

                                // 思考过程流 (DeepSeek-R1 / OpenAI o-series)
                                if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                                    continuation.yield(.reasoning(reasoning))
                                }
                                // 正式回答正文流
                                if let chunk = delta["content"] as? String, !chunk.isEmpty {
                                    continuation.yield(.content(chunk))
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
