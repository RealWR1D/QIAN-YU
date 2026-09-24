//
//  ChatMessage.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftData

@Model
public final class ChatMessage: Identifiable {
    public var id: UUID = UUID()
    public var role: String = "assistant" // "user" | "assistant" | "system"
    public var content: String = ""
    public var timestamp: Date = Date()
    public var isStreaming: Bool = false
    public var tag: String? = nil // "chat", "course_alert", "routine_greeting"
    public var reasoningContent: String? = nil // 思考/推理内容 (Thinking/Reasoning tokens)

    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        tag: String? = nil,
        reasoningContent: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.tag = tag
        self.reasoningContent = reasoningContent
    }
}
