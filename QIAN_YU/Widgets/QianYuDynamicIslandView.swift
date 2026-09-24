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

#if canImport(WidgetKit) && canImport(ActivityKit) && os(iOS)

public struct QianYuPomodoroLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // 锁屏横幅与实时通知视图
            PomodoroLockScreenLiveView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // 1. 展开态 - 顶部左侧 (小陈头像槽位与状态，坚决无剑标)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        QianYuChibiMiniAvatarView(size: 22)
                        Text(context.state.sessionTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.leading, 4)
                }

                // 2. 展开态 - 顶部右侧 (倒计时大数字)
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.trailing, 4)
                }

                // 3. 展开态 - 底部进度与说明
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(context.state.isPaused ? Color.secondary : Color.orange)

                        HStack {
                            Text("陈千语 · 伴读中")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(context.state.isPaused ? "已暂停" : "保持专注")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(context.state.isPaused ? .secondary : .orange)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // 紧凑左侧：小陈头像插槽 (无剑标，预留 Q 版插图)
                QianYuChibiMiniAvatarView(size: 18)
            } compactTrailing: {
                // 紧凑右侧：倒计时分秒
                Text(context.state.formattedTime)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            } minimal: {
                // 极简态：微缩头像
                QianYuChibiMiniAvatarView(size: 16)
            }
        }
    }
}

// MARK: - 锁屏实时活动横幅
struct PomodoroLockScreenLiveView: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            QianYuChibiMiniAvatarView(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(state.sessionTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)

                    Spacer()

                    Text(state.formattedTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }

                ProgressView(value: state.progress)
                    .tint(.orange)

                HStack {
                    Text("陈千语 · 正在陪你专注")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(state.isPaused ? "已暂停" : "计时中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground).opacity(0.92))
    }
}

// MARK: - 灵动岛小陈微缩头像槽位 (无剑标，优先展示 Q 版插图)
public struct QianYuChibiMiniAvatarView: View {
    public let size: CGFloat

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            if let uiImg = UIImage(named: "qianyu_chibi_avatar") ?? UIImage(named: "chen_qianyu_avatar") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)

                Text("千")
                    .font(.system(size: max(8, size * 0.55), weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
#endif
