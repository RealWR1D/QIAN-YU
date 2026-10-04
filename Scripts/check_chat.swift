import Foundation
import Security
import SwiftData

final class ChatKeyStore: APIKeyStorage {
    func read(account: String, legacy: Bool) -> (value: String?, status: OSStatus) { (nil, errSecItemNotFound) }
    func write(_ value: String, account: String) -> Bool { true }
}
actor ChatStreamFixture {
    private var continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation?
    private(set) var requests: [[ChatRequestMessage]] = []
    func stream(messages: [ChatRequestMessage]) -> AsyncThrowingStream<StreamChunk, Error> {
        requests.append(messages)
        return AsyncThrowingStream { continuation = $0 }
    }
    func emit(_ text: String) { continuation?.yield(.content(text)) }
    func fail() { continuation?.finish(throwing: URLError(.networkConnectionLost)); continuation = nil }
    func finish() { continuation?.finish(); continuation = nil }
}
@main struct ChatRegressionChecks {
    @MainActor static func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        preconditionFailure("Chat operation did not complete")
    }
    @MainActor static func main() async throws {
        let suite = "qianyu.chat.regression.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults, keyStore: ChatKeyStore())
        settings.apiKey = "fixture-key"
        settings.apiBaseURL = "https://fixture.invalid/v1"
        settings.modelName = "fixture-model"
        let container = try ModelContainer(for: ChatMessage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let fixture = ChatStreamFixture()
        let model = ChatViewModel(settings: settings, streamProvider: { _, _, _, _, messages in
            await fixture.stream(messages: messages)
        })
        model.setContext(context)
        let welcomeID = model.currentSessionMessages[0].id
        model.inputText = "这个学期有什么课？"
        model.sendMessage(scheduleContext: "完整课表：课程甲 周一 08:00 A101；课程乙 周二 10:00 B202。")
        for _ in 0..<2000 {
            if await !fixture.requests.isEmpty { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let assistant = model.currentSessionMessages.last!
        precondition(model.isGenerating && assistant.isStreaming)
        let request = await fixture.requests[0]
        precondition(request[0].content.contains("课程甲") && request[0].content.contains("课程乙"))
        // A tab reattaches its context before the first token, during streaming, and after completion.
        model.setContext(context)
        precondition(model.isGenerating && assistant.isStreaming && model.currentSessionMessages.count == 3)
        precondition(model.currentSessionMessages[0].id == welcomeID)
        model.setVisible(false)
        await fixture.emit("课程甲")
        try await waitFor { assistant.content == "课程甲" }
        model.setVisible(true)
        model.setContext(context)
        precondition(model.historyMessages.isEmpty && model.currentSessionMessages.last?.id == assistant.id)
        await fixture.emit("、课程乙")
        await fixture.finish()
        try await waitFor { !model.isGenerating }
        precondition(assistant.content == "课程甲、课程乙" && !assistant.isStreaming)
        model.setContext(context)
        precondition(model.currentSessionMessages.count == 3 && model.historyMessages.isEmpty)
        let persisted = try context.fetch(FetchDescriptor<ChatMessage>())
        precondition(persisted.count == 2 && persisted.contains { $0.content == "课程甲、课程乙" })
        model.inputText = "再说一次"
        model.sendMessage()
        for _ in 0..<2000 {
            if await fixture.requests.count == 2 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let requestCount = await fixture.requests.count
        precondition(requestCount == 2)
        model.clearAllMessages()
        await fixture.emit("已清空后不应出现的文字")
        await fixture.finish()
        try await Task.sleep(for: .milliseconds(20))
        precondition(!model.isGenerating && model.currentSessionMessages.count == 1)
        let cleared = try context.fetch(FetchDescriptor<ChatMessage>())
        precondition(cleared.isEmpty)
        model.inputText = "网络中断测试"
        model.sendMessage()
        for _ in 0..<2000 { if await fixture.requests.count >= 3 { break }; try await Task.sleep(for:.milliseconds(1)) }
        await fixture.emit("保留这段正文")
        await fixture.fail()
        try await waitFor { !model.isGenerating }
        precondition(model.currentSessionMessages.last?.content == "保留这段正文")
        precondition(model.currentSessionMessages.last?.generationError != nil)
        let offline = QianYuDialogueCorpus.matchReply(for:"明天有什么课", scheduleContext:"应用计算指令，不应显示\n课程：本学期课程\n查询日期：2026-10-05；课程：课程甲 08:00 教室：A101。")
        precondition(offline.contains("A101") && !offline.contains("应用计算指令") && !offline.contains("本学期课程"))
        let messageCount = model.currentSessionMessages.count
        model.retryLastResponse()
        for _ in 0..<2000 { if await fixture.requests.count >= 4 { break }; try await Task.sleep(for:.milliseconds(1)) }
        let revision = model.renderRevision
        for _ in 0..<500 { await fixture.emit("字") }
        await fixture.finish()
        try await waitFor { !model.isGenerating }
        precondition(model.currentSessionMessages.count == messageCount)
        precondition(model.currentSessionMessages.last?.content.count == 500)
        precondition(model.renderRevision - revision < 20, "Stream bursts must be batched rather than redrawing per token")
        let batchedUpdates = model.renderRevision - revision
        model.inputText = "停止后保留正文"
        model.sendMessage()
        for _ in 0..<2000 { if await fixture.requests.count >= 5 { break }; try await Task.sleep(for:.milliseconds(1)) }
        await fixture.emit("停止前已生成")
        try await waitFor { model.currentSessionMessages.last?.content == "停止前已生成" }
        model.cancelGeneration()
        await fixture.emit("停止后不应出现")
        await fixture.finish()
        try await Task.sleep(for:.milliseconds(20))
        precondition(!model.isGenerating && model.currentSessionMessages.last?.content == "停止前已生成")
        precondition(model.currentSessionMessages.last?.generationError != nil)
        let failing = ChatViewModel(modelContext:context, settings:settings, saveContext:{ _ in throw CocoaError(.fileWriteOutOfSpace) })
        precondition(!failing.persistMessages() && failing.saveErrorMessage != nil)
        model.clearAllMessages()
        for i in 0..<95 { context.insert(ChatMessage(role:"user", content:"old-\(i)", timestamp:Date(timeIntervalSince1970: Double(i)))) }
        try context.save()
        model.refreshHistory()
        precondition(model.historyMessages.count == 40 && model.historyCount == 95)
        model.loadMoreHistory(); precondition(model.historyMessages.count == 80)
        model.loadMoreHistory(); precondition(model.historyMessages.count == 95 && !model.hasMoreHistory)
        model.clearAllMessages()
        let emptyCount = try context.fetchCount(FetchDescriptor<ChatMessage>())
        precondition(emptyCount == 0)
        print("Chat checks passed: hidden-page generation, partial response retention, stopping, retry without duplicates, 500 chunks in \(batchedUpdates) UI updates, saving failures, 40-message pagination and clearing all records")
    }
}
