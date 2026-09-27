//
//  QianYuDynamicIslandView.swift
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

// MARK: - 灵动岛小陈微缩头像槽位 (跨平台支持，严禁剑标，优先展示小陈立绘)
public struct QianYuChibiMiniAvatarView: View {
    public let size: CGFloat

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            #if os(macOS)
            if let nsImg = NSImage(named: "qianyu_chibi_avatar") ?? NSImage(named: "QianyuAvatar") {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
            #else
            if let uiImg = UIImage(named: "qianyu_chibi_avatar") ?? UIImage(named: "QianyuAvatar") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
            #endif
        }
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)

            Text("千")
                .font(.system(size: max(8, size * 0.55), weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#if canImport(WidgetKit) && canImport(ActivityKit) && os(iOS)

public struct QianYuPomodoroLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // 锁屏实时活动横幅
            PomodoroLockScreenLiveView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // 1. 展开态 - 顶部左侧 (小陈特勤干员头像与伴读身份，严格无剑标)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        QianYuChibiMiniAvatarView(size: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.sessionTitle)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)

                            Text("陈千语 · 随行伴读")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                // 2. 展开态 - 顶部右侧 (倒计时大字与暂停/运行状态)
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.formattedTime)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(context.state.isPaused ? .secondary : .orange)

                        Text(context.state.isPaused ? "已暂停" : "保持专注")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(context.state.isPaused ? .secondary : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(context.state.isPaused ? Color.secondary.opacity(0.2) : Color.orange.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 4)
                }

                // 3. 展开态 - 中间 (千语原声高情商口头禅与鼓励气泡)
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 6) {
                        Text(context.state.quote.isEmpty ? "「当破即破，冲冲冲！」" : context.state.quote)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }

                // 4. 展开态 - 底部进度指示
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        ProgressView(value: context.state.progress)
                            .tint(context.state.isPaused ? Color.secondary : Color.orange)

                        HStack {
                            Text("总轮次 \(context.state.totalSeconds / 60) 分钟")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            let percent = Int(context.state.progress * 100)
                            Text("已完成 \(percent)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            } compactLeading: {
                // 紧凑左侧：小陈微缩头像 (带温暖细橙环，坚决无剑标)
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    QianYuChibiMiniAvatarView(size: 18)
                }
            } compactTrailing: {
                // 紧凑右侧：倒计时分秒或暂停图标
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                } else {
                    Text(context.state.formattedTime)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            } minimal: {
                // 极简独立态：微缩头像配合环形微进度指示
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(context.state.progress))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 20, height: 20)
                    QianYuChibiMiniAvatarView(size: 16)
                }
            }
        }
    }
}

// MARK: - 锁屏实时活动横幅 (Lock Screen Live Activity Banner)
public struct PomodoroLockScreenLiveView: View {
    public let state: PomodoroActivityAttributes.ContentState

    public init(state: PomodoroActivityAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 14) {
            // 小陈伴读头像
            QianYuChibiMiniAvatarView(size: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("千语伴读 · \(state.sessionTitle)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)

                    Spacer()

                    Text(state.formattedTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(state.isPaused ? .secondary : .primary)
                }

                Text(state.quote.isEmpty ? "「当破即破，冲冲冲！」" : state.quote)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                ProgressView(value: state.progress)
                    .tint(state.isPaused ? Color.secondary : Color.orange)

                HStack {
                    Text(state.isPaused ? "已暂停" : "专注进行中")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(state.isPaused ? .secondary : .orange)

                    Spacer()

                    let percent = Int(state.progress * 100)
                    Text("\(percent)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground).opacity(0.95))
    }
}

#endif
