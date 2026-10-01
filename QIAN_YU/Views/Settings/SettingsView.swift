//
//  SettingsView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct SettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @Bindable public var scheduleViewModel: CourseScheduleViewModel
    @State private var isShowingAPIKey: Bool = false
    @State private var nameNotificationRefresh: Task<Void, Never>?
    @State private var isShowingModelPicker = false

    public init(viewModel: SettingsViewModel, scheduleViewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
        self.scheduleViewModel = scheduleViewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 伙伴称呼设置
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "伙伴称呼"), icon: "person.text.rectangle")

                    SettingsCardContainer {
                        SettingsRow(label: String(localized: "称呼")) {
                            TextField("例如：管理员", text: $viewModel.settings.userName)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: viewModel.settings.userName) { _, _ in
                                    nameNotificationRefresh?.cancel()
                                    nameNotificationRefresh = Task {
                                        try? await Task.sleep(for: .milliseconds(400))
                                        guard !Task.isCancelled else { return }
                                        NotificationManager.shared.scheduleDailyNotifications()
                                    }
                                }
                        }
                    }

                    Text("千语日常闲聊与推送提醒时对你的尊称，在终末地工业默认为「管理员」。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                // 3. 每日提醒与通知设置入口
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "每日提醒与通知"), icon: "bell.badge.fill")

                    SettingsCardContainer {
                        NavigationLink {
                            DailyPushSettingsView(viewModel: viewModel, scheduleViewModel: scheduleViewModel)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("每日提醒与上课通知")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("清晨唤醒 · 饭点提醒 · 穴位放松 · 深夜关怀 · 课前预警")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("点击进入配置清晨、午休、傍晚等四大定点陪伴推送与课前课后提醒时间。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                // 4. 小组件与灵动岛入口
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "小组件与灵动岛"), icon: "square.grid.2x2.fill")

                    SettingsCardContainer {
                        NavigationLink {
                            WidgetPreviewSettingView()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("小组件与灵动岛全览")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("桌面 2x2 小组件 · 锁屏单行/圆形/长条 · 灵动岛 4 种实时伴读形态")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("即时查看 2x2 桌面组件与锁屏组件显示效果，并可真机一键拉起灵动岛实时伴读测试。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                apiConfigurationSection

                // 4. 关于应用
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "关于应用"), icon: "info.circle")

                    SettingsCardContainer {
                        SettingsInfoRow(label: String(localized: "应用名称"), value: "QIAN YU")
                        Divider().padding(.leading, 126)
                        SettingsInfoRow(label: String(localized: "设计规范"), value: String(localized: "Apple HIG · SwiftUI 原生跨平台"))
                        Divider().padding(.leading, 126)
                        SettingsInfoRow(label: String(localized: "版本号"), value: "1.0.0")
                        Divider().padding(.leading, 126)
                        NavigationLink {
                            PersonaDocView(settings: viewModel.settings)
                        } label: {
                            HStack(spacing: 16) {
                                Text("角色人设")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 90, alignment: .leading)
                                Spacer()
                                Text("陈千语")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.qianyuSettingsBg)
        .navigationTitle("设置与偏好")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: viewModel.settings.configurationRevision) {
            viewModel.configurationDidChange()
        }
        .onDisappear {
            viewModel.cancelRequests()
        }
        .sheet(isPresented: $isShowingModelPicker) {
            ModelSelectionView(viewModel: viewModel)
        }
    }

    private var thinkingConfiguration: ThinkingConfiguration {
        LLMThinkingCapabilities.configuration(
            baseURL: viewModel.settings.apiBaseURL,
            model: viewModel.settings.modelName
        )
    }

    private var apiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: String(localized: "AI 模型驱动 (OpenAI 协议兼容)"), icon: "sparkles")
            SettingsCardContainer {
                SettingsRow(label: String(localized: "服务商预设")) {
                    Picker("", selection: Binding(
                        get: { viewModel.currentProvider },
                        set: { viewModel.applyPreset(provider: $0) }
                    )) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                Divider().padding(.leading, 126)
                SettingsRow(label: String(localized: "接口地址")) {
                    TextField("https://...", text: $viewModel.settings.apiBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
                Divider().padding(.leading, 126)
                SettingsRow(label: String(localized: "选择模型")) {
                    Button {
                        isShowingModelPicker = true
                    } label: {
                        HStack {
                            Text(viewModel.settings.modelName.isEmpty ? String(localized: "选择模型") : viewModel.settings.modelName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("modelSelectionButton")
                }
                Divider().padding(.leading, 126)
                SettingsRow(label: String(localized: "模型 ID")) {
                    TextField("也可手动填写完整模型 ID", text: $viewModel.settings.modelName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
                Divider().padding(.leading, 126)
                SettingsRow(label: "API Key") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if isShowingAPIKey {
                                TextField("输入 API Key", text: $viewModel.settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                            } else {
                                SecureField("输入 API Key", text: $viewModel.settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button {
                                isShowingAPIKey.toggle()
                            } label: {
                                Image(systemName: isShowingAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .help(isShowingAPIKey ? "隐藏 API Key" : "显示 API Key")
                        }
                        Text(viewModel.settings.isLocalAPIEndpoint
                             ? "本机接口可留空；若服务要求密钥，仍需填写。"
                             : "API Key 按服务商分别保存在系统钥匙串中。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if let error = viewModel.settings.apiKeyStorageError {
                            Text(error).font(.system(size: 11)).foregroundStyle(.red)
                            Button("重新尝试保存") { viewModel.settings.retryAPIKeySave() }
                                .font(.system(size: 11))
                        }
                        #if os(macOS)
                        if viewModel.settings.legacyAPIKeyNeedsMigration {
                            Button("重新尝试迁移旧 API Key") {
                                viewModel.settings.retryLegacyAPIKeyMigration()
                            }
                            .font(.system(size: 11))
                        }
                        #endif
                    }
                }
                Divider().padding(.leading, 126)
                SettingsRow(label: String(localized: "思考强度")) {
                    Picker("", selection: Binding(
                        get: { thinkingConfiguration.effectiveValue(for: viewModel.settings.thinkingEffort) },
                        set: { viewModel.settings.thinkingEffort = $0 }
                    )) {
                        ForEach(thinkingConfiguration.options) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
            Text(thinkingConfiguration.explanation)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(viewModel.configurationStatusText)
                    .foregroundStyle(statusColor)
                Spacer()
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 4)
            if let message = viewModel.connectionTestMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.refreshModels() }
                } label: {
                    Label(viewModel.isLoadingModels ? "正在读取…" : "刷新模型列表", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingModels)
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    Label(viewModel.isTestingConnection ? "正在验证…" : "测试当前配置", systemImage: "checkmark.shield")
                }
                .disabled(viewModel.isTestingConnection || !viewModel.settings.isAPIConfigured || viewModel.settings.apiKeyStorageError != nil)
            }
            .buttonStyle(.bordered)
            if let message = viewModel.modelListMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var statusIcon: String {
        switch viewModel.configurationStatus {
        case .incomplete: "circle.dotted"
        case .saved: "checkmark.circle"
        case .verified: "checkmark.shield.fill"
        case .invalid: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.configurationStatus {
        case .incomplete: .secondary
        case .saved: .orange
        case .verified: .green
        case .invalid: .red
        }
    }

}

private struct ModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    @State private var search = ""

    private var matches: [String] {
        search.isEmpty ? viewModel.availableModels : viewModel.availableModels.filter {
            $0.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(matches, id: \.self) { model in
                        Button {
                            viewModel.selectModel(model)
                            dismiss()
                        } label: {
                            HStack {
                                Text(model)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if model == viewModel.settings.modelName {
                                    Image(systemName: "checkmark").foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    Text("当前模型：\(viewModel.settings.modelName)")
                } footer: {
                    if let message = viewModel.modelListMessage { Text(message) }
                }
                Button {
                    Task { await viewModel.refreshModels() }
                } label: {
                    Label(viewModel.isLoadingModels ? "正在读取…" : "刷新服务端模型列表", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingModels)
            }
            .searchable(text: $search, prompt: "搜索模型 ID")
            .navigationTitle("选择模型")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 专属排版组件，严格确保 macOS/iOS 左对齐与间距对齐

/// 区域标题
struct SettingsSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.orange)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(.leading, 4)
    }
}

/// 圆角白底卡片容器
struct SettingsCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color.qianyuCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

/// 严格统一标签宽度的输入行，实现 100% 对齐
struct SettingsRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 90, alignment: .leading)

            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// 展示信息的静态行
struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// 跨平台背景色兼容
extension Color {
    #if os(macOS)
    static let qianyuSettingsBg = Color(nsColor: .windowBackgroundColor)
    static let qianyuCardBg = Color(nsColor: .controlBackgroundColor)
    #else
    static let qianyuSettingsBg = Color(uiColor: .systemGroupedBackground)
    static let qianyuCardBg = Color(uiColor: .secondarySystemGroupedBackground)
    #endif
}
