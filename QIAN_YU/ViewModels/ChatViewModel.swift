//
//  ChatViewModel.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@Observable
@MainActor
public final class ChatViewModel {
    /// 往期历史对话（进入 App 时默认折叠收起）
    public var historyMessages: [ChatMessage] = []
    /// 本次运行/当前会话产生的对话
    public var currentSessionMessages: [ChatMessage] = []
    /// 历史记录是否展开
    public var isHistoryExpanded: Bool = false

    public var inputText: String = ""
    public var isGenerating: Bool = false
    public var currentStatus: String = QianYuDialogueCorpus.randomStatus()

    private var modelContext: ModelContext?
    private var generationTask: Task<Void, Never>?
    private var generationID: UUID?

    public init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    public func setContext(_ context: ModelContext) {
        self.modelContext = context
        self.loadHistory()
    }

    /// 进入 App 时加载历史记录，并将历史记录收起
    public func loadHistory() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        if let saved = try? context.fetch(descriptor) {
            // 清理可能因为 App 异常退出而残留在数据库中的 isStreaming: true
            var needsSave = false
            for msg in saved where msg.isStreaming {
                msg.isStreaming = false
                if msg.content.isEmpty {
                    msg.content = EditorialCopy.text("dialogue.interrupted")
                }
                needsSave = true
            }
            if needsSave {
                try? context.save()
            }

            // 将历史消息存入 historyMessages，进入时默认折叠收起
            self.historyMessages = saved
            self.isHistoryExpanded = false
        }

        // 初始化当前会话的千语首句问候
        let welcome = ChatMessage(
            role: "assistant",
            content: EditorialCopy.text("dialogue.welcome")
        )
        self.currentSessionMessages = [welcome]
    }

    /// 发送消息（支持云端 LLM 流式输出与离线拟真快速回复）
    public func sendMessage(upcomingCourseHint: String? = nil) {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isGenerating else { return }

        inputText = ""
        sendCustomMessage(content: content, upcomingCourseHint: upcomingCourseHint)
    }

    /// 发送快捷预设提示词（如“按按肩颈”、“大院趣事”等）
    public func sendQuickPrompt(_ prompt: String, upcomingCourseHint: String? = nil) {
        guard !isGenerating else { return }
        sendCustomMessage(content: prompt, upcomingCourseHint: upcomingCourseHint)
    }

    private func sendCustomMessage(content: String, upcomingCourseHint: String? = nil) {
        // 1. 插入用户消息并存入本地数据库
        let userMsg = ChatMessage(role: "user", content: content)
        currentSessionMessages.append(userMsg)
        modelContext?.insert(userMsg)
        triggerHaptic()

        // 2. 准备千语助手气泡，并【必须】插入数据库注册以持久化
        let assistantMsg = ChatMessage(role: "assistant", content: "", isStreaming: true)
        currentSessionMessages.append(assistantMsg)
        modelContext?.insert(assistantMsg) // 解决小陈回复未持久化保存的关键修复
        isGenerating = true
        let currentGenerationID = UUID()
        generationID = currentGenerationID

        let settings = AppSettings.shared

        // 3. 本地兼容接口可无密钥；其余接口需要已配置的 API Key。
        if settings.isAPIConfigured {
            // 云端 LLM 流式调用
            generationTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let systemPrompt = PersonaEngine.shared.buildSystemPrompt(
                        userName: settings.userName,
                        upcomingCourseHint: upcomingCourseHint
                    )
                    var requestMessages = [ChatRequestMessage(role: "system", content: systemPrompt)]

                    // 汇总历史与当前上下文（取最近 10 轮以维持紧凑）
                    let combined = (historyMessages + currentSessionMessages).dropLast().suffix(10)
                    for msg in combined {
                        requestMessages.append(ChatRequestMessage(role: msg.role, content: msg.content))
                    }

                    let stream = await LLMService.shared.streamChat(
                        baseURL: settings.apiBaseURL,
                        apiKey: settings.apiKey,
                        model: settings.modelName,
                        thinkingEffort: settings.thinkingEffort,
                        messages: requestMessages
                    )

                    for try await chunk in stream {
                        guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id),
                              !Task.isCancelled else { return }
                        switch chunk {
                        case .content(let text):
                            assistantMsg.content += text
                            triggerLightHaptic()
                        case .reasoning(let reasoningText):
                            if assistantMsg.reasoningContent == nil {
                                assistantMsg.reasoningContent = ""
                            }
                            assistantMsg.reasoningContent? += reasoningText
                        }
                    }
                    guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id),
                          !Task.isCancelled else { return }
                    if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        assistantMsg.content = EditorialCopy.text("dialogue.emptyModelReply")
                    }
                    assistantMsg.isStreaming = false
                    try? self.modelContext?.save()
                    self.finishGeneration(currentGenerationID)
                } catch {
                    guard !Task.isCancelled,
                          self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id) else {
                        return
                    }
                    assistantMsg.content = EditorialCopy.text("dialogue.requestFailed", ["error": error.localizedDescription])
                    assistantMsg.isStreaming = false
                    try? self.modelContext?.save()
                    self.finishGeneration(currentGenerationID)
                }
            }
        } else {
            // 离线高质量千语原设台词模拟打字机输出
            generationTask = Task { [weak self] in
                guard let self else { return }
                let reply = QianYuDialogueCorpus.matchReply(
                    for: content,
                    userName: settings.userName,
                    nextCourseSummary: upcomingCourseHint
                )

                // 拟真打字机逐字输出效果
                for char in reply {
                    do {
                        try await Task.sleep(nanoseconds: 28_000_000) // 28ms 节奏
                    } catch {
                        return
                    }
                    guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id),
                          !Task.isCancelled else { return }
                    assistantMsg.content.append(char)
                }
                guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id) else { return }
                assistantMsg.isStreaming = false
                try? self.modelContext?.save()
                self.finishGeneration(currentGenerationID)
            }
        }
    }

    private func isCurrentGeneration(_ id: UUID, assistantMessageID: UUID) -> Bool {
        generationID == id && currentSessionMessages.contains { $0.id == assistantMessageID }
    }

    private func finishGeneration(_ id: UUID) {
        guard generationID == id else { return }
        generationTask = nil
        generationID = nil
        isGenerating = false
        currentStatus = QianYuDialogueCorpus.randomStatus()
    }

    /// 离开聊天页时保存已生成内容；清空记录时直接取消后删除。
    public func cancelGeneration(savePartialResponse: Bool = true) {
        generationTask?.cancel()
        generationTask = nil
        generationID = nil
        isGenerating = false

        if let assistantMessage = currentSessionMessages.last(where: { $0.role == "assistant" && $0.isStreaming }) {
            assistantMessage.isStreaming = false
            if savePartialResponse {
                if assistantMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    assistantMessage.content = EditorialCopy.text("dialogue.cancelled")
                }
                try? modelContext?.save()
            }
        }
    }

    /// 清空所有聊天记录（包括往期历史与当前会话）
    public func clearAllMessages() {
        cancelGeneration(savePartialResponse: false)
        guard let context = modelContext else { return }
        for msg in historyMessages {
            if msg.modelContext != nil {
                context.delete(msg)
            }
        }
        for msg in currentSessionMessages {
            if msg.modelContext != nil {
                context.delete(msg)
            }
        }
        historyMessages.removeAll()
        currentSessionMessages.removeAll()
        try? context.save()
        loadHistory()
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    private func triggerLightHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.3)
        #endif
    }
}
