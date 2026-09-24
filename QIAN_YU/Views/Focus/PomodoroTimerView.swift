//
//  PomodoroTimerView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct PomodoroTimerView: View {
    @State private var viewModel = PomodoroTimerViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 1. 顶部模式选择器 (专注 / 小憩)
                HStack(spacing: 12) {
                    ForEach(PomodoroTimerViewModel.SessionMode.allCases) { mode in
                        let isSelected = viewModel.mode == mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.setMode(mode)
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(
                                    isSelected
                                        ? (mode == .focus ? Color.orange : Color.green)
                                        : Color.secondary.opacity(0.1)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.state == .running || viewModel.state == .paused)
                    }
                }
                .padding(.top, 16)

                // 2. 小陈陪伴插图槽位 (预留 Q 版图片展示区，无剑标)
                QianYuChibiSlotView(
                    isFocusing: viewModel.mode == .focus && viewModel.state == .running
                )

                // 3. 核心倒计时大圆环
                ZStack {
                    // 背景底环
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 14)
                        .frame(width: 250, height: 250)

                    // 进度环
                    Circle()
                        .trim(from: 0.0, to: CGFloat(viewModel.progress))
                        .stroke(
                            viewModel.mode == .focus ? Color.orange : Color.green,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: viewModel.progress)
                        .frame(width: 250, height: 250)

                    // 内部时间与状态文本
                    VStack(spacing: 8) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)

                        Text(viewModel.statusCaption)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // 4. 预设时长选择药丸标签 (仅在未开始时可选)
                if viewModel.state == .idle || viewModel.state == .completed {
                    HStack(spacing: 10) {
                        let presets = viewModel.mode == .focus ? viewModel.focusPresets : viewModel.breakPresets
                        ForEach(presets, id: \.self) { mins in
                            let isCurrent = viewModel.selectedMinutes == mins
                            Button {
                                withAnimation {
                                    viewModel.selectMinutes(mins)
                                }
                            } label: {
                                Text("\(mins) 分钟")
                                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? (viewModel.mode == .focus ? .orange : .green) : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        isCurrent
                                            ? (viewModel.mode == .focus ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                                            : Color.secondary.opacity(0.08)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 5. 底部核心控制按钮
                HStack(spacing: 20) {
                    switch viewModel.state {
                    case .idle:
                        Button {
                            withAnimation {
                                viewModel.start()
                            }
                        } label: {
                            Label(viewModel.mode == .focus ? "开始专注" : "开始小憩", systemImage: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 180, height: 48)
                                .background(viewModel.mode == .focus ? Color.orange : Color.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                    case .running:
                        Button {
                            withAnimation {
                                viewModel.pause()
                            }
                        } label: {
                            Label("暂停", systemImage: "pause.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 44)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation {
                                viewModel.reset()
                            }
                        } label: {
                            Text("重置")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 90, height: 44)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                    case .paused:
                        Button {
                            withAnimation {
                                viewModel.resume()
                            }
                        } label: {
                            Label("继续", systemImage: "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 44)
                                .background(viewModel.mode == .focus ? Color.orange : Color.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation {
                                viewModel.reset()
                            }
                        } label: {
                            Text("放弃重置")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 90, height: 44)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                    case .completed:
                        Button {
                            withAnimation {
                                viewModel.reset()
                                viewModel.start()
                            }
                        } label: {
                            Label("再来一轮", systemImage: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 180, height: 48)
                                .background(viewModel.mode == .focus ? Color.orange : Color.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("专注番茄钟")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 小陈专属插图插槽组件 (预留稍后填入的 Q 版图片，不包含任何剑标)
public struct QianYuChibiSlotView: View {
    public let isFocusing: Bool

    public init(isFocusing: Bool = false) {
        self.isFocusing = isFocusing
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 76, height: 76)

                // 优先检查稍后添加的 "qianyu_chibi_avatar"，如果不存在则使用现有头像或优雅首字母徽章
                #if os(macOS)
                if let nsImg = NSImage(named: "qianyu_chibi_avatar") ?? NSImage(named: "chen_qianyu_avatar") {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
                #else
                if let uiImg = UIImage(named: "qianyu_chibi_avatar") ?? UIImage(named: "chen_qianyu_avatar") {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
                #endif
            }
            .overlay(
                Circle()
                    .stroke(isFocusing ? Color.orange : Color.clear, lineWidth: 2)
                    .scaleEffect(isFocusing ? 1.08 : 1.0)
                    .animation(isFocusing ? Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: isFocusing)
            )

            Text("陈千语 · 伴读中")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.orange, .pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 70, height: 70)

            Text("千语")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
