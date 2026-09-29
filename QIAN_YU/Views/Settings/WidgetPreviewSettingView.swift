//
//  WidgetPreviewSettingView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

public struct WidgetPreviewSettingView: View {
    @State private var previewMode: PreviewCategory = .homeSmall
    @State private var isSimulatingNoClass: Bool = false
    @State private var isLiveActivityActive: Bool = false
    @State private var testRemainingSeconds: Int = 24 * 60 + 50
    @State private var isTestPaused: Bool = false

    public enum PreviewCategory: String, CaseIterable, Identifiable {
        case homeSmall = "桌面 2x2"
        case lockScreen = "锁屏组件"
        case dynamicIsland = "灵动岛"

        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .homeSmall: return String(localized: "桌面 2x2")
            case .lockScreen: return String(localized: "锁屏组件")
            case .dynamicIsland: return String(localized: "灵动岛")
            }
        }
    }

    public init() {}

    private var sampleEntry: CourseWidgetEntry {
        if isSimulatingNoClass {
            return CourseWidgetEntry(
                date: Date(),
                courseName: "今日已无课",
                classroom: "",
                timeString: "",
                teacher: "",
                weekInfo: AppSettings.shared.currentWeekDisplay,
                isNoClass: true
            )
        } else {
            return CourseWidgetEntry(
                date: Date(),
                courseName: String(localized: "高等数学 (上)"),
                classroom: String(localized: "正心楼 312"),
                timeString: "08:30 - 10:05",
                teacher: String(localized: "张教授"),
                weekInfo: String(localized: "第 4 周 · 双周"),
                isNoClass: false
            )
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 顶部模式选择器
                Picker("组件类型", selection: $previewMode) {
                    ForEach(PreviewCategory.allCases) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 2. 状态切换器 (有课 / 无课)
                if previewMode != .dynamicIsland {
                    HStack {
                        Text("模拟课程状态：")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Picker("", selection: $isSimulatingNoClass) {
                            Text("即将上课").tag(false)
                            Text("今日无课").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)

                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // 3. 核心效果展示画板
                VStack(spacing: 16) {
                    switch previewMode {
                    case .homeSmall:
                        homeSmallPreviewSection
                    case .lockScreen:
                        lockScreenPreviewSection
                    case .dynamicIsland:
                        dynamicIslandPreviewSection
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

                // 4. 灵动岛真机实测控制器 (仅在灵动岛分类展示)
                #if os(iOS)
                if previewMode == .dynamicIsland {
                    dynamicIslandActionCard
                        .padding(.horizontal)
                }
                #endif

                // 5. iOS 添加与使用指南
                guideInstructionSection
                    .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("小组件与灵动岛")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - 桌面 2x2 小组件展示区
    private var homeSmallPreviewSection: some View {
        VStack(spacing: 14) {
            Text("桌面 2x2 系统小号组件 (System Small)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 模拟 iOS 桌面图标网格容器
            ZStack {
                #if os(iOS)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                #else
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                #endif

                CourseWidgetEntryView(entry: sampleEntry).smallView
            }
            .frame(width: 165, height: 165)
            .padding(.vertical, 8)

            Text("长按 iPhone 桌面空白处，点击左上角「+」即可添加。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 锁屏小组件展示区
    private var lockScreenPreviewSection: some View {
        VStack(spacing: 20) {
            Text("iOS 锁屏小组件全套形态 (iOS 16+)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 模拟锁屏深色背景
            VStack(spacing: 16) {
                // 1. 锁屏时间上方单行
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. 锁屏单行组件 (Accessory Inline)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        #if os(iOS)
                        CourseWidgetEntryView(entry: sampleEntry).inlineLockScreenView
                        #else
                        Text("下节: 高等数学 08:30")
                        #endif
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // 2. 锁屏圆形与长矩形并排
                HStack(spacing: 20) {
                    // 圆形组件
                    VStack(alignment: .center, spacing: 6) {
                        Text("2. 圆形 (Circular)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 66, height: 66)

                            #if os(iOS)
                            CourseWidgetEntryView(entry: sampleEntry).circularLockScreenView
                            #else
                            Text("高数")
                            #endif
                        }
                    }

                    // 矩形组件
                    VStack(alignment: .leading, spacing: 6) {
                        Text("3. 矩形 (Rectangular)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.secondary.opacity(0.15))

                            #if os(iOS)
                            CourseWidgetEntryView(entry: sampleEntry).rectangularLockScreenView
                                .padding(10)
                            #else
                            Text("下节课详情")
                            #endif
                        }
                        .frame(height: 66)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 灵动岛展示区
    private var dynamicIslandPreviewSection: some View {
        VStack(spacing: 20) {
            Text("灵动岛 4 种实时形态 (Dynamic Island)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 1. 紧凑态 (双侧药丸)
            VStack(alignment: .leading, spacing: 6) {
                Text("紧凑态 (左右药丸)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    ZStack {
                        Circle()
                            .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        QianYuChibiMiniAvatarView(size: 18)
                    }

                    Spacer()

                    Text("24:50")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.black)
                .clipShape(Capsule())
            }

            // 2. 极简态 (独立圆环)
            VStack(alignment: .leading, spacing: 6) {
                Text("极简态 (与其他 App 共享灵动岛时)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .trim(from: 0, to: 0.65)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 24, height: 24)
                        QianYuChibiMiniAvatarView(size: 18)
                    }
                    .frame(width: 36, height: 36)
                    .background(Color.black)
                    .clipShape(Circle())
                    Spacer()
                }
            }

            // 3. 展开态 (长按灵动岛)
            VStack(alignment: .leading, spacing: 6) {
                Text("展开态 (长按灵动岛展开大卡片)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                VStack(spacing: 10) {
                    HStack(alignment: .top) {
                        HStack(spacing: 8) {
                            QianYuChibiMiniAvatarView(size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("专注中")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("陈千语 · 随行伴读")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("24:50")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                            Text("保持专注")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }

                    // 中间千语台词
                    HStack {
                        Text("「当破即破，冲冲冲！」")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())

                    // 底部进度
                    VStack(spacing: 4) {
                        ProgressView(value: 0.35)
                            .tint(.orange)
                        HStack {
                            Text("总轮次 25 分钟")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("已完成 35%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(14)
                .background(Color.black)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            // 4. 锁屏实时活动横幅
            VStack(alignment: .leading, spacing: 6) {
                Text("锁屏实时横幅 (Lock Screen Live Activity)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                #if os(iOS) && canImport(ActivityKit)
                let sampleState = PomodoroActivityAttributes.ContentState(
                    remainingSeconds: 24 * 60 + 50,
                    totalSeconds: 25 * 60,
                    isPaused: false,
                    sessionTitle: "专注中",
                    quote: "「吸气、呼气、一口气做完！」"
                )
                PomodoroLockScreenLiveView(state: sampleState)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                #else
                HStack(spacing: 14) {
                    QianYuChibiMiniAvatarView(size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("千语伴读 · 专注中")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                            Spacer()
                            Text("24:50")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                        }
                        Text("「吸气、呼气、一口气做完！」")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        ProgressView(value: 0.35)
                            .tint(.orange)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                #endif
            }
        }
    }

    // MARK: - 灵动岛实机控制测试卡片
    #if os(iOS)
    @State private var feedbackText: String? = nil

    private var dynamicIslandActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("灵动岛真机实测控制")
                .font(.system(size: 14, weight: .bold))

            HStack(spacing: 12) {
                Button {
                    let success = LiveActivityManager.shared.startPomodoro(
                        sessionTitle: "专注中",
                        totalSeconds: 25 * 60,
                        remainingSeconds: 24 * 60 + 50,
                        quote: "「当破即破，冲冲冲！」"
                    )
                    if success {
                        isLiveActivityActive = true
                        feedbackText = String(localized: "✅ 灵动岛已成功升起！退回桌面或锁屏即可看到陈千语伴读浮岛。")
                    } else {
                        isLiveActivityActive = false
                        feedbackText = String(localized: "⚠️ 未能升起：请前往 iPhone「设置 -> QIAN YU -> 实时活动」确认开关已开启。")
                    }
                } label: {
                    Label("启动灵动岛", systemImage: "play.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    LiveActivityManager.shared.endPomodoro()
                    isLiveActivityActive = false
                    feedbackText = String(localized: "已收回灵动岛实时活动。")
                } label: {
                    Label("收回灵动岛", systemImage: "stop.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let fb = feedbackText {
                HStack(spacing: 6) {
                    Text(fb)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isLiveActivityActive ? .orange : .secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("点击「启动灵动岛」后，可返回 iPhone 主屏幕或锁屏，即可在支持灵动岛的机型上看到实时浮动伴读！")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    #endif

    // MARK: - 添加教程
    private var guideInstructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("如何添加小组件与启用灵动岛")
                .font(.system(size: 14, weight: .bold))

            VStack(alignment: .leading, spacing: 10) {
                GuideStepRow(
                    step: "1",
                    title: String(localized: "添加桌面 2x2 小组件"),
                    desc: String(localized: "在 iPhone 主屏幕长按空白区域至应用图标抖动 -> 点击左上角「+」-> 搜索「QIAN YU」-> 选择 2x2 尺寸卡片点击「添加小组件」。")
                )

                GuideStepRow(
                    step: "2",
                    title: String(localized: "添加锁屏小组件"),
                    desc: String(localized: "在锁屏状态下长按屏幕 -> 点击「自定」-> 选择「锁定屏幕」-> 点击时钟下方或上方的小组件插槽 -> 添加「QIAN YU」课程表或专注组件。")
                )

                GuideStepRow(
                    step: "3",
                    title: String(localized: "开启灵动岛实时活动"),
                    desc: String(localized: "确保在 iPhone「系统设置 -> QIAN YU」中将「实时活动」开关保持打开。开启番茄钟专注后，灵动岛将自动升起伴读。")
                )
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 辅助步骤行组件
struct GuideStepRow: View {
    let step: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text(step)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
