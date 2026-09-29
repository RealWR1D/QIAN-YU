//
//  SettingsViewModel.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import CryptoKit
import Foundation
import SwiftUI

public enum APIConfigurationStatus {
    case incomplete
    case saved
    case verified
    case invalid
}

@Observable
@MainActor
public final class SettingsViewModel {
    public typealias ModelLoader = @Sendable (String, String) async throws -> [String]
    public typealias ConnectionValidator = @Sendable (String, String, String, String) async throws -> Void

    public var settings: AppSettings
    public var isAuthorizedForNotification: Bool = false
    public var testNotificationMessage: String = ""
    public var isShowingPersonaSheet: Bool = false
    public private(set) var isLoadingModels = false
    public private(set) var isTestingConnection = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let modelLoader: ModelLoader
    @ObservationIgnored private let connectionValidator: ConnectionValidator
    @ObservationIgnored private var modelsTask: Task<[String], Error>?
    @ObservationIgnored private var connectionTask: Task<Void, Error>?
    @ObservationIgnored private var modelsRequestID: UUID?
    @ObservationIgnored private var connectionRequestID: UUID?
    @ObservationIgnored private var modelsRequestConfigurationID: String?
    @ObservationIgnored private var connectionRequestConfigurationID: String?

    private var modelLists: [String: [String]] = [:]
    private var modelFeedback: [String: String] = [:]
    private var connectionChecks: [String: ConnectionCheck]

    private struct ConnectionCheck: Codable {
        let configurationID: String
        let checkedAt: Date
        let failure: String?
    }

    private static let checksDefaultsKey = "qianyu_api_connection_checks_v1"

    public var currentProvider: LLMProvider {
        get {
            LLMProvider.allCases.first { $0.code == settings.selectedProviderRaw } ?? .deepseek
        }
        set {
            applyPreset(provider: newValue)
        }
    }

    /// Keep a manually entered model selectable even when a server omits it from /models.
    public var availableModels: [String] {
        let current = settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = modelLists[modelsConfigurationID] ?? currentProvider.recommendedModels
        return Array(Set(([current] + candidates).filter { !$0.isEmpty })).sorted()
    }

    public var modelListMessage: String? {
        modelFeedback[modelsConfigurationID]
            ?? String(localized: "尚未读取服务端模型列表。预设仅供参考；点击刷新可读取当前 API Key 可见的全部模型，也可手动填写模型 ID。")
    }

    public var configurationStatus: APIConfigurationStatus {
        if settings.apiKeyStorageError != nil { return .invalid }
        if configurationProblem != nil { return .incomplete }
        guard let check = currentConnectionCheck else { return .saved }
        return check.failure == nil ? .verified : .invalid
    }

    public var configurationStatusText: String {
        if isTestingConnection { return String(localized: "正在验证当前模型与思考配置…") }
        if settings.apiKeyStorageError != nil { return String(localized: "API Key 保存失败") }
        switch configurationStatus {
        case .incomplete:
            return configurationProblem ?? String(localized: "配置未完成")
        case .saved:
            return String(localized: "配置已保存，尚未验证")
        case .verified:
            return String(localized: "当前配置已通过连接测试")
        case .invalid:
            return String(localized: "连接测试未通过")
        }
    }

    public var connectionTestMessage: String? {
        if let error = settings.apiKeyStorageError { return error }
        guard let check = currentConnectionCheck else { return nil }
        if let failure = check.failure { return failure }
        let date = check.checkedAt.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "上次验证：\(date)。修改地址、密钥、模型或思考配置后需要重新测试。")
    }

    public init(
        settings: AppSettings = .shared,
        defaults: UserDefaults = .standard,
        checkNotificationPermissions: Bool = true,
        modelLoader: @escaping ModelLoader = { baseURL, apiKey in
            try await LLMService.shared.fetchModels(baseURL: baseURL, apiKey: apiKey)
        },
        connectionValidator: @escaping ConnectionValidator = { baseURL, apiKey, model, effort in
            try await LLMService.shared.validateConfiguration(
                baseURL: baseURL, apiKey: apiKey, model: model, thinkingEffort: effort
            )
        }
    ) {
        self.settings = settings
        self.defaults = defaults
        self.modelLoader = modelLoader
        self.connectionValidator = connectionValidator
        if let data = defaults.data(forKey: Self.checksDefaultsKey),
           let checks = try? JSONDecoder().decode([String: ConnectionCheck].self, from: data) {
            self.connectionChecks = checks
        } else {
            self.connectionChecks = [:]
        }
        if checkNotificationPermissions {
            Task { [weak self] in await self?.checkPermissions() }
        }
    }

    public func checkPermissions() async {
        self.isAuthorizedForNotification = await NotificationManager.shared.checkAuthorizationStatus()
    }

    public func requestNotificationPermission() async {
        let granted = await NotificationManager.shared.requestAuthorization()
        self.isAuthorizedForNotification = granted
        if granted {
            NotificationManager.shared.scheduleDailyNotifications()
        }
    }

    public func applyPreset(provider: LLMProvider) {
        guard provider.code != settings.selectedProviderRaw else { return }
        let activated = settings.activateProvider(
            code: provider.code,
            defaultURL: provider.defaultURL,
            defaultModel: provider.recommendedModels.first ?? ""
        )
        if activated { configurationDidChange() }
    }

    public func selectModel(_ model: String) {
        settings.modelName = model
        configurationDidChange()
    }

    /// Called after edits; an old request must never verify or populate a new configuration.
    public func configurationDidChange() {
        if let requestConfiguration = modelsRequestConfigurationID,
           requestConfiguration != modelsConfigurationID {
            cancelModelRequest()
        }
        if let requestConfiguration = connectionRequestConfigurationID,
           requestConfiguration != connectionConfigurationID {
            cancelConnectionRequest()
        }
    }

    public func refreshModels() async {
        cancelModelRequest()
        let configurationID = modelsConfigurationID
        guard let problem = modelConfigurationProblem else {
            let requestID = UUID()
            modelsRequestID = requestID
            modelsRequestConfigurationID = configurationID
            isLoadingModels = true
            let baseURL = settings.apiBaseURL
            let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let loader = modelLoader
            let task = Task { try await loader(baseURL, apiKey) }
            modelsTask = task
            defer {
                if modelsRequestID == requestID { finishModelRequest() }
            }
            do {
                let models = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                guard !Task.isCancelled, modelsRequestID == requestID,
                      configurationID == modelsConfigurationID else { return }
                let cleaned = Array(Set(models.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })).sorted()
                modelLists[configurationID] = cleaned
                if cleaned.isEmpty {
                    modelFeedback[configurationID] = String(localized: "服务端返回了空模型列表。可以手动填写模型 ID，再测试该模型的连接。")
                } else {
                    modelFeedback[configurationID] = String(localized: "已读取 \(cleaned.count) 个服务端模型。列表可能包含非对话模型；请选定后测试连接。")
                }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError),
                      modelsRequestID == requestID, configurationID == modelsConfigurationID else { return }
                modelFeedback[configurationID] = String(localized: "读取模型列表失败：\(safeErrorDescription(error, apiKey: apiKey))。仍可手动填写模型 ID 并测试连接。")
            }
            return
        }
        modelFeedback[configurationID] = problem
    }

    /// Explicit user action: uses the same request configuration as an actual conversation.
    public func testConnection() async {
        cancelConnectionRequest()
        guard configurationProblem == nil, settings.apiKeyStorageError == nil else { return }
        let configurationID = connectionConfigurationID
        let providerCode = settings.selectedProviderRaw
        let requestID = UUID()
        connectionRequestID = requestID
        connectionRequestConfigurationID = configurationID
        isTestingConnection = true
        let baseURL = settings.apiBaseURL
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effort = settings.thinkingEffort
        let validator = connectionValidator
        let task = Task { try await validator(baseURL, apiKey, model, effort) }
        connectionTask = task
        defer {
            if connectionRequestID == requestID { finishConnectionRequest() }
        }
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard !Task.isCancelled, connectionRequestID == requestID,
                  configurationID == connectionConfigurationID else { return }
            recordCheck(provider: providerCode, configurationID: configurationID, failure: nil)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError),
                  connectionRequestID == requestID, configurationID == connectionConfigurationID else { return }
            recordCheck(provider: providerCode, configurationID: configurationID,
                        failure: safeErrorDescription(error, apiKey: apiKey))
        }
    }

    public func cancelRequests() {
        cancelModelRequest()
        cancelConnectionRequest()
    }

    private var modelConfigurationProblem: String? {
        guard (try? OpenAICompatibleEndpoint.chatCompletionsURL(from: settings.apiBaseURL)) != nil else {
            return String(localized: "请填写有效的 HTTP 或 HTTPS API 地址")
        }
        if !settings.isLocalAPIEndpoint,
           settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "尚未填写 API Key")
        }
        return nil
    }

    private var configurationProblem: String? {
        if let problem = modelConfigurationProblem { return problem }
        if settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "尚未填写模型 ID")
        }
        return nil
    }

    private var modelsConfigurationID: String {
        fingerprint([
            settings.selectedProviderRaw,
            normalizedBaseURL,
            settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
    }

    private var connectionConfigurationID: String {
        fingerprint([
            modelsConfigurationID,
            settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            settings.thinkingEffort
        ])
    }

    private var normalizedBaseURL: String {
        (try? OpenAICompatibleEndpoint.chatCompletionsURL(from: settings.apiBaseURL).absoluteString)
            ?? settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentConnectionCheck: ConnectionCheck? {
        guard let check = connectionChecks[settings.selectedProviderRaw],
              check.configurationID == connectionConfigurationID else { return nil }
        return check
    }

    private func fingerprint(_ values: [String]) -> String {
        // Store only a digest, never API credentials, in validation metadata.
        let data = (try? JSONEncoder().encode(values)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func recordCheck(provider: String, configurationID: String, failure: String?) {
        connectionChecks[provider] = ConnectionCheck(
            configurationID: configurationID, checkedAt: Date(), failure: failure
        )
        if let data = try? JSONEncoder().encode(connectionChecks) {
            defaults.set(data, forKey: Self.checksDefaultsKey)
        }
    }

    private func safeErrorDescription(_ error: Error, apiKey: String) -> String {
        let message = error.localizedDescription
        return apiKey.isEmpty ? message : message.replacingOccurrences(of: apiKey, with: "[REDACTED]")
    }

    private func finishModelRequest() {
        modelsTask = nil
        modelsRequestID = nil
        modelsRequestConfigurationID = nil
        isLoadingModels = false
    }

    private func finishConnectionRequest() {
        connectionTask = nil
        connectionRequestID = nil
        connectionRequestConfigurationID = nil
        isTestingConnection = false
    }

    private func cancelModelRequest() {
        modelsTask?.cancel()
        finishModelRequest()
    }

    private func cancelConnectionRequest() {
        connectionTask?.cancel()
        finishConnectionRequest()
    }

    public func triggerTestPush() {
        testNotificationMessage = EditorialCopy.text("settings.testNotification.scheduling")
        NotificationManager.shared.sendTestNotification { success in
            if success {
                self.testNotificationMessage = EditorialCopy.text("settings.testNotification.sent")
            } else {
                self.testNotificationMessage = EditorialCopy.text("settings.testNotification.failed")
            }
        }
    }

    public func updateDailySchedules() {
        NotificationManager.shared.scheduleDailyNotifications()
    }
}

public enum LLMProvider: String, CaseIterable, Identifiable {
    case deepseek = "DeepSeek (推荐)"
    case mimo = "小米 MiMo"
    case openai = "OpenAI"
    case siliconflow = "硅基流动 (SiliconFlow)"
    case ollama = "本地 Ollama"
    case custom = "自定义服务商"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: return String(localized: "DeepSeek (推荐)")
        case .mimo: return String(localized: "小米 MiMo")
        case .openai: return "OpenAI"
        case .siliconflow: return String(localized: "硅基流动 (SiliconFlow)")
        case .ollama: return String(localized: "本地 Ollama")
        case .custom: return String(localized: "自定义服务商")
        }
    }

    public var code: String {
        switch self {
        case .deepseek: return "deepseek"
        case .mimo: return "mimo"
        case .openai: return "openai"
        case .siliconflow: return "siliconflow"
        case .ollama: return "ollama"
        case .custom: return "custom"
        }
    }

    public var defaultURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/chat/completions"
        case .mimo: return "https://api.xiaomimimo.com/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .siliconflow: return "https://api.siliconflow.cn/v1/chat/completions"
        case .ollama: return "http://localhost:11434/v1/chat/completions"
        case .custom: return ""
        }
    }

    public var recommendedModels: [String] {
        switch self {
        case .deepseek:
            return ["deepseek-flash", "deepseek-v4-pro"]
        case .mimo:
            return ["mimo-v2.6-flash"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "o3-mini"]
        case .siliconflow:
            return ["deepseek-ai/DeepSeek-V3", "deepseek-ai/DeepSeek-R1", "Qwen/Qwen2.5-7B-Instruct"]
        case .ollama:
            return ["llama3:8b", "qwen2.5:7b", "deepseek-r1:8b"]
        case .custom:
            return []
        }
    }
}
