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
    public private(set) var historyCount = 0
    public var hasMoreHistory: Bool { historyMessages.count < historyCount }
    public var saveErrorMessage: String?
    public private(set) var renderRevision = 0
    @ObservationIgnored private var isVisible = true
    @ObservationIgnored private var sessionStartedAt = Date()
    @ObservationIgnored private var pendingContent = ""
    @ObservationIgnored private var pendingReasoning = ""
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var lastCheckpoint = Date()
    @ObservationIgnored private var lastRequest: (String, String?, String?)?
    @ObservationIgnored private let saveContext: (ModelContext) throws -> Void

    public var inputText: String = ""
    public var isGenerating: Bool = false
    public var currentStatus: String = QianYuDialogueCorpus.randomStatus()

    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    @ObservationIgnored private let settings: AppSettings
    public typealias StreamProvider = @Sendable (String, String, String, String, [ChatRequestMessage]) async -> AsyncThrowingStream<StreamChunk, Error>
    @ObservationIgnored private let streamProvider: StreamProvider
    private var generationTask: Task<Void, Never>?
    private var generationID: UUID?

    public init(modelContext: ModelContext? = nil, settings: AppSettings = .shared, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() },
                streamProvider: @escaping StreamProvider = { baseURL, apiKey, model, effort, messages in
                    await LLMService.shared.streamChat(baseURL: baseURL, apiKey: apiKey, model: model, thinkingEffort: effort, messages: messages)
                }) {
        self.modelContext = modelContext
        self.settings = settings
        self.streamProvider = streamProvider
        self.saveContext = saveContext
    }

    public func setContext(_ context: ModelContext) {
        if modelContext === context && hasLoadedHistory { return }
        self.modelContext = context
        self.loadHistory()
    }

    /// 进入 App 时加载历史记录，并将历史记录收起
    public func loadHistory() {
        guard modelContext != nil else { return }
        hasLoadedHistory = true
        refreshHistory()

        // 初始化当前会话的千语首句问候
        let welcome = ChatMessage(
            role: "assistant",
            content: EditorialCopy.text("dialogue.welcome")
        )
        self.currentSessionMessages = [welcome]
    }

    public func refreshHistory() {
        historyMessages = []
        loadMoreHistory()
    }

    public func loadMoreHistory() {
        guard let context = modelContext else { return }
        let cutoff = sessionStartedAt
        var descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.timestamp < cutoff }, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchOffset = historyMessages.count
        descriptor.fetchLimit = 40
        do {
            historyCount = try context.fetchCount(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.timestamp < cutoff }))
            let page = try context.fetch(descriptor)
            for message in page where message.isStreaming {
                message.isStreaming = false
                message.generationError = String(localized: "上次回复未完成")
            }
            historyMessages.insert(contentsOf: page.reversed(), at: 0)
            persistMessages()
        } catch { saveErrorMessage = String(localized: "读取聊天记录失败：") + error.localizedDescription }
    }

    @discardableResult public func persistMessages() -> Bool {
        guard let context = modelContext else { return true }
        do { try saveContext(context); saveErrorMessage = nil; return true }
        catch { saveErrorMessage = String(localized: "聊天记录尚未保存：") + error.localizedDescription; return false }
    }

    public func setVisible(_ visible: Bool) {
        isVisible = visible
        checkpoint()
    }

    private var refreshInterval: Int {
        if !isVisible { return 500 }
        let process = ProcessInfo.processInfo
        return process.isLowPowerModeEnabled || process.thermalState == .serious || process.thermalState == .critical ? 250 : 100
    }

    public func checkpoint() {
        if let message = currentSessionMessages.last, message.isStreaming { flushPending(into: message) }
        persistMessages()
    }

    private func flushPending(into message: ChatMessage) {
        guard !pendingContent.isEmpty || !pendingReasoning.isEmpty else { return }
        message.content += pendingContent
        if !pendingReasoning.isEmpty { message.reasoningContent = (message.reasoningContent ?? "") + pendingReasoning }
        pendingContent = ""; pendingReasoning = ""
        renderRevision += 1
        if Date().timeIntervalSince(lastCheckpoint) >= 5 {
            persistMessages(); lastCheckpoint = Date()
        }
    }

    public func retryLastResponse() {
        guard !isGenerating, let request = lastRequest else { return }
        sendCustomMessage(content: request.0, upcomingCourseHint: request.1, scheduleContext: request.2, retrying: true)
    }

    /// 发送消息（支持云端 LLM 流式输出与离线拟真快速回复）
    public func sendMessage(upcomingCourseHint: String? = nil, scheduleContext: String? = nil) {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isGenerating else { return }

        inputText = ""
        sendCustomMessage(content: content, upcomingCourseHint: upcomingCourseHint, scheduleContext: scheduleContext)
    }

    /// 发送快捷预设提示词（如“按按肩颈”、“大院趣事”等）
    public func sendQuickPrompt(_ prompt: String, upcomingCourseHint: String? = nil, scheduleContext: String? = nil) {
        guard !isGenerating else { return }
        sendCustomMessage(content: prompt, upcomingCourseHint: upcomingCourseHint, scheduleContext: scheduleContext)
    }

    private func sendCustomMessage(content: String, upcomingCourseHint: String? = nil, scheduleContext: String? = nil, retrying: Bool = false) {
        let assistantMsg: ChatMessage
        if retrying, let last = currentSessionMessages.last, last.role == "assistant" {
            assistantMsg = last
            last.content = ""; last.reasoningContent = nil; last.generationError = nil; last.isStreaming = true
        } else {
            let userMsg = ChatMessage(role: "user", content: content)
            currentSessionMessages.append(userMsg); modelContext?.insert(userMsg)
            assistantMsg = ChatMessage(role: "assistant", content: "", isStreaming: true)
            currentSessionMessages.append(assistantMsg); modelContext?.insert(assistantMsg)
        }
        lastRequest = (content, upcomingCourseHint, scheduleContext)
        pendingContent = ""; pendingReasoning = ""
        lastCheckpoint = Date()
        persistMessages()
        triggerHaptic()
        isGenerating = true
        let currentGenerationID = UUID()
        generationID = currentGenerationID

        flushTask?.cancel()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.refreshInterval else { return }
                do { try await Task.sleep(for: .milliseconds(interval)) } catch { return }
                guard let self, self.generationID == currentGenerationID else { return }
                self.flushPending(into: assistantMsg)
            }
        }
        let settings = self.settings

        // 3. 本地兼容接口可无密钥；其余接口需要已配置的 API Key。
        if settings.isAPIConfigured {
            // 云端 LLM 流式调用
            generationTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let systemPrompt = PersonaEngine(settings: settings).buildSystemPrompt(
                        userName: settings.userName,
                        upcomingCourseHint: upcomingCourseHint,
                        scheduleContext: scheduleContext
                    )
                    var requestMessages = [ChatRequestMessage(role: "system", content: systemPrompt)]

                    // 汇总历史与当前上下文（取最近 10 轮以维持紧凑）
                    let combined = (historyMessages + currentSessionMessages).dropLast().suffix(10)
                    for msg in combined {
                        requestMessages.append(ChatRequestMessage(role: msg.role, content: msg.content))
                    }

                    let stream = await self.streamProvider(settings.apiBaseURL, settings.apiKey,
                        settings.modelName, settings.thinkingEffort, requestMessages)

                    for try await chunk in stream {
                        guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id),
                              !Task.isCancelled else { return }
                        switch chunk {
                        case .content(let text):
                            pendingContent += text
                        case .reasoning(let reasoningText):
                            pendingReasoning += reasoningText
                        }
                    }
                    guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id),
                          !Task.isCancelled else { return }
                    self.flushPending(into: assistantMsg)
                    if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        assistantMsg.content = EditorialCopy.text("dialogue.emptyModelReply")
                    }
                    assistantMsg.isStreaming = false
                    self.persistMessages()
                    self.finishGeneration(currentGenerationID)
                } catch {
                    guard !Task.isCancelled,
                          self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id) else {
                        return
                    }
                    self.flushPending(into: assistantMsg)
                    assistantMsg.generationError = error.localizedDescription
                    if assistantMsg.content.isEmpty { assistantMsg.content = EditorialCopy.text("dialogue.requestFailed", ["error": error.localizedDescription]) }
                    assistantMsg.isStreaming = false
                    self.persistMessages()
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
                    nextCourseSummary: upcomingCourseHint,
                    scheduleContext: scheduleContext
                )

                self.flushTask?.cancel(); self.flushTask = nil
                let characters = Array(reply)
                for offset in stride(from: 0, to: characters.count, by: 4) {
                    do { try await Task.sleep(for: .milliseconds(max(110, self.refreshInterval))) } catch { return }
                    guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id), !Task.isCancelled else { return }
                    pendingContent += String(characters[offset..<min(offset + 4, characters.count)])
                    self.flushPending(into: assistantMsg)
                }
                guard self.isCurrentGeneration(currentGenerationID, assistantMessageID: assistantMsg.id) else { return }
                self.flushPending(into: assistantMsg)
                assistantMsg.isStreaming = false
                self.persistMessages()
                self.finishGeneration(currentGenerationID)
            }
        }
    }

    private func isCurrentGeneration(_ id: UUID, assistantMessageID: UUID) -> Bool {
        generationID == id && currentSessionMessages.contains { $0.id == assistantMessageID }
    }

    private func finishGeneration(_ id: UUID) {
        guard generationID == id else { return }
        flushTask?.cancel(); flushTask = nil
        generationTask = nil
        generationID = nil
        isGenerating = false
        currentStatus = QianYuDialogueCorpus.randomStatus()
    }

    /// 显式停止时保存已生成内容；切换页面继续生成，清空记录时取消后删除。
    public func cancelGeneration(savePartialResponse: Bool = true) {
        generationTask?.cancel()
        flushTask?.cancel(); flushTask = nil
        generationTask = nil
        generationID = nil
        isGenerating = false

        if let assistantMessage = currentSessionMessages.last(where: { $0.role == "assistant" && $0.isStreaming }) {
            flushPending(into: assistantMessage)
            assistantMessage.isStreaming = false
            assistantMessage.generationError = String(localized: "回复已停止")
            if savePartialResponse {
                if assistantMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    assistantMessage.content = EditorialCopy.text("dialogue.cancelled")
                }
                persistMessages()
            }
        }
    }

    /// 清空所有聊天记录（包括往期历史与当前会话）
    public func clearAllMessages() {
        cancelGeneration(savePartialResponse: false)
        guard let context = modelContext else { return }
        do { try context.delete(model: ChatMessage.self) }
        catch { saveErrorMessage = error.localizedDescription; return }
        guard persistMessages() else { context.rollback(); return }
        historyMessages.removeAll()
        currentSessionMessages.removeAll()
        lastRequest = nil
        sessionStartedAt = Date()
        loadHistory()
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

}
