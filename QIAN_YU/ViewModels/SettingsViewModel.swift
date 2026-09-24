//
//  SettingsViewModel.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI

@Observable
@MainActor
public final class SettingsViewModel {
    public var settings = AppSettings.shared
    public var isAuthorizedForNotification: Bool = false
    public var testNotificationMessage: String = ""
    public var isShowingPersonaSheet: Bool = false

    public var currentProvider: LLMProvider {
        get {
            LLMProvider.allCases.first { $0.code == settings.selectedProviderRaw } ?? .deepseek
        }
        set {
            settings.selectedProviderRaw = newValue.code
        }
    }

    public init() {
        Task {
            await self.checkPermissions()
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
        currentProvider = provider
        if provider != .custom {
            settings.apiBaseURL = provider.defaultURL
            if let firstModel = provider.recommendedModels.first {
                settings.modelName = firstModel
            }
        }
    }

    public func selectModel(_ model: String) {
        settings.modelName = model
    }

    public func triggerTestPush() {
        testNotificationMessage = "正在安排测试通知，3秒后送达……"
        NotificationManager.shared.sendTestNotification { success in
            if success {
                self.testNotificationMessage = "✅ 通知已发出！请留意系统弹窗通知。"
            } else {
                self.testNotificationMessage = "❌ 发送失败，请检查系统通知权限。"
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
            return ["deepseek-chat", "deepseek-reasoner"]
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
