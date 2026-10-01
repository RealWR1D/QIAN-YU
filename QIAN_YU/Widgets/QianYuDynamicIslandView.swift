//
//  QianYuDynamicIslandView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - 灵动岛小陈微缩头像槽位 (跨平台支持，严禁剑标，优先展示小陈立绘)
public struct QianYuChibiMiniAvatarView: View {
    public let size: CGFloat
    public let assetName: String
    @Environment(\.displayScale) private var displayScale

    public init(size: CGFloat = 20, assetName: String = "QianyuFocusAvatar") {
        self.size = size
        self.assetName = assetName
    }

    public var body: some View {
        ZStack {
            #if os(macOS)
            if let nsImg = NSImage(named: assetName) {
                Image(nsImage: nsImg)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
            #else
            if let uiImg = QianYuLiveAvatarRenderer.image(assetName: assetName, diameter: size, scale: displayScale) {
                Image(uiImage: uiImg)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
            #endif
        }
        .frame(width: size, height: size)
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

#if os(iOS)
/// ActivityKit 校验的是图片本身的尺寸；SwiftUI 的 frame 不会缩小原始位图。
enum QianYuLiveAvatarRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(assetName: String = "QianyuFocusAvatar", diameter: CGFloat, scale: CGFloat) -> UIImage? {
        let key = "\(assetName):\(diameter)@\(scale)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = UIImage(named: assetName, in: .main, compatibleWith: nil) else { return nil }
        let image = thumbnail(from: source, diameter: diameter, scale: scale)
        cache.setObject(image, forKey: key)
        return image
    }

    static func thumbnail(from source: UIImage, diameter: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, scale)
        format.opaque = false
        let target = CGSize(width: diameter, height: diameter)
        let ratio = max(diameter / source.size.width, diameter / source.size.height)
        let scaled = CGSize(width: source.size.width * ratio, height: source.size.height * ratio)
        let rect = CGRect(
            x: (diameter - scaled.width) / 2,
            y: (diameter - scaled.height) / 2,
            width: scaled.width,
            height: scaled.height
        )
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: rect)
        }.withRenderingMode(.alwaysOriginal)
    }
}
#endif

// 圆环描边保持在边界内，右侧留出 4pt，避免被灵动岛的摄像头区域裁切。
public struct QianYuCompactAvatarView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5)
            QianYuChibiMiniAvatarView(size: 18)
        }
        .frame(width: 22, height: 22)
        .frame(width: 26, height: 24, alignment: .leading)
    }
}

#if canImport(WidgetKit) && canImport(ActivityKit) && os(iOS)

public struct QianYuPomodoroLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // 锁屏实时活动横幅
            PomodoroLockScreenLiveView(state: context.state, isStale: context.isStale)
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
                        PomodoroActivityCountdown(state: context.state)
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(context.state.isPaused ? .secondary : .orange)

                        Text(context.state.isPaused ? "已暂停" : (context.isStale ? "本轮已到时" : "保持专注"))
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
                        PomodoroActivityProgress(state: context.state)
                            .tint(context.state.isPaused ? Color.secondary : Color.orange)

                        HStack {
                            Text("总轮次 \(context.state.totalSeconds / 60) 分钟")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            PomodoroActivityCountdown(state: context.state, width: 40)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            } compactLeading: {
                // 紧凑左侧：小陈微缩头像 (带温暖细橙环，坚决无剑标)
                QianYuCompactAvatarView()
            } compactTrailing: {
                // 紧凑右侧：倒计时分秒或暂停图标
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                } else {
                    PomodoroActivityCountdown(state: context.state, width: 54)
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.orange)
                }
            } minimal: {
                // 极简独立态：微缩头像与静态描边，避免显示后台冻结的进度
                ZStack {
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    QianYuChibiMiniAvatarView(size: 16)
                }
                .padding(1)
            }
        }
    }
}

/// These system-rendered views continue counting down without ActivityKit updates.
private struct PomodoroActivityCountdown: View {
    let state: PomodoroActivityAttributes.ContentState
    var width: CGFloat = 80

    var body: some View {
        Group {
            if let interval = state.timerInterval {
                Text(timerInterval: interval, countsDown: true, showsHours: false)
                    .monospacedDigit()
            } else {
                Text(state.formattedTime)
            }
        }
        // Timer text fills its proposed width; align the glyphs as well as the frame.
        .multilineTextAlignment(.trailing)
        // Keep a finite width so the system renderer can safely lay out timer text.
        .frame(width: width, alignment: .trailing)
    }
}

private struct PomodoroActivityProgress: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        if let interval = state.timerInterval {
            ProgressView(timerInterval: interval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        } else {
            ProgressView(value: state.progress)
        }
    }
}

// MARK: - 锁屏实时活动横幅 (Lock Screen Live Activity Banner)
public struct PomodoroLockScreenLiveView: View {
    public let state: PomodoroActivityAttributes.ContentState
    public let isStale: Bool

    public init(state: PomodoroActivityAttributes.ContentState, isStale: Bool = false) {
        self.state = state
        self.isStale = isStale
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

                    PomodoroActivityCountdown(state: state)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(state.isPaused ? .secondary : .primary)
                }

                Text(state.quote.isEmpty ? "「当破即破，冲冲冲！」" : state.quote)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                PomodoroActivityProgress(state: state)
                    .tint(state.isPaused ? Color.secondary : Color.orange)

                HStack {
                    Text(state.isPaused ? "已暂停" : (isStale ? "本轮已到时" : "专注进行中"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(state.isPaused ? .secondary : .orange)

                    Spacer()

                    Text("总轮次 \(state.totalSeconds / 60) 分钟")
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
