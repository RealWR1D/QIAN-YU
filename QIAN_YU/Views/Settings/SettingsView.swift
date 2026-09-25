//
//  SettingsView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct SettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @State private var isShowingAPIKey: Bool = false

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 伙伴称呼设置
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "伙伴称呼", icon: "person.text.rectangle")

                    SettingsCardContainer {
                        SettingsRow(label: "称呼") {
                            TextField("例如：管理员", text: $viewModel.settings.userName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Text("千语日常闲聊与推送提醒时对你的尊称，在终末地工业默认为「管理员」。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                // 2. 角色人设档案入口
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "角色人设", icon: "person.crop.circle.badge.checkmark")

                    SettingsCardContainer {
                        Button {
                            viewModel.isShowingPersonaSheet = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 36, height: 36)
                                    Image("QianyuAvatar")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 34, height: 34)
                                        .clipShape(Circle())
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("陈千语 · 完整人设规范与台词语料")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("宏山城龙族姑娘 · 终末地特勤干员 · 双剑客 · 说话规范")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
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
                }

                // 3. 每日提醒与通知设置入口
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "每日提醒与通知", icon: "bell.badge.fill")

                    SettingsCardContainer {
                        NavigationLink {
                            DailyPushSettingsView(viewModel: viewModel)
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

                // 4. 大模型服务端配置
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "AI 模型驱动 (OpenAI 协议兼容)", icon: "sparkles")

                    SettingsCardContainer {
                        // 1. 服务商切换
                        SettingsRow(label: "服务商预设") {
                            Picker("", selection: Binding(
                                get: { viewModel.currentProvider },
                                set: { viewModel.applyPreset(provider: $0) }
                            )) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 2. 该服务商下的快捷模型选择 (如果该服务商提供了预设列表)
                        if !viewModel.currentProvider.recommendedModels.isEmpty {
                            Divider().padding(.leading, 126)

                            SettingsRow(label: "选择模型") {
                                Picker("", selection: Binding(
                                    get: {
                                        viewModel.currentProvider.recommendedModels.contains(viewModel.settings.modelName)
                                            ? viewModel.settings.modelName
                                            : (viewModel.currentProvider.recommendedModels.first ?? "")
                                    },
                                    set: { viewModel.selectModel($0) }
                                )) {
                                    ForEach(viewModel.currentProvider.recommendedModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Divider().padding(.leading, 126)

                        // 3. 接口地址
                        SettingsRow(label: "接口地址") {
                            TextField("https://...", text: $viewModel.settings.apiBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                        }

                        Divider().padding(.leading, 126)

                        // 4. 具体模型名称 (可直接编辑自定义)
                        SettingsRow(label: "模型名称") {
                            TextField("输入或从上方选择模型", text: $viewModel.settings.modelName)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                        }

                        Divider().padding(.leading, 126)

                        // 5. API Key
                        SettingsRow(label: "API Key") {
                            HStack(spacing: 8) {
                                if isShowingAPIKey {
                                    TextField("如 sk-...", text: $viewModel.settings.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                        #if os(iOS)
                                        .textInputAutocapitalization(.never)
                                        #endif
                                } else {
                                    SecureField("已加密保存在本地设备", text: $viewModel.settings.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button {
                                    isShowingAPIKey.toggle()
                                } label: {
                                    Image(systemName: isShowingAPIKey ? "eye.slash" : "eye")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, height: 28)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .help(isShowingAPIKey ? "隐藏 API Key" : "显示 API Key")
                            }
                        }

                        Divider().padding(.leading, 126)

                        // 6. 思考强度 (Thinking Effort)
                        SettingsRow(label: "思考强度") {
                            Picker("", selection: $viewModel.settings.thinkingEffort) {
                                ForEach(ThinkingEffortOption.allCases) { option in
                                    Text(option.displayName).tag(option.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // 离线/在线与速度优化说明条
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                                .padding(.top, 1)

                            Text("提速建议：千语设定为极简口语（30~80字），推荐将「思考强度」设为「关闭 (极速直答)」，或在模型中选用 deepseek-chat 等对话模型，避免深度推理（o1/o3/R1 思维链）带来的漫长等待。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // 4. 关于应用
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: "关于应用", icon: "info.circle")

                    SettingsCardContainer {
                        SettingsInfoRow(label: "应用名称", value: "QIAN YU (千语伴行)")
                        Divider().padding(.leading, 126)
                        SettingsInfoRow(label: "设计规范", value: "Apple HIG · SwiftUI 原生跨平台")
                        Divider().padding(.leading, 126)
                        SettingsInfoRow(label: "版本号", value: "1.0.0")
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
        .sheet(isPresented: $viewModel.isShowingPersonaSheet) {
            PersonaDocView()
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
