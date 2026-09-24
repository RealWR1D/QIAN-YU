//
//  MessageBubbleView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct MessageBubbleView: View {
    public let message: ChatMessage
    @State private var isShowingReasoning: Bool = false

    public var isUser: Bool {
        message.role == "user"
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !isUser {
                // 陈千语专属头像徽章
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.orange.opacity(0.3), radius: 3, x: 0, y: 1)

                    Image("QianyuAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // 若处于思考阶段且正文尚未产生
                if !isUser && message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(message.reasoningContent != nil ? "💭 千语正在深入琢磨中……" : "千语正在回信……")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    // 正文气泡主体
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 15))
                            .foregroundColor(isUser ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isUser
                                    ? Color.orange
                                    : Color.secondary.opacity(0.12)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // 思考过程查看标签（如果模型输出了思维链）
                    if !isUser, let reasoning = message.reasoningContent, !reasoning.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isShowingReasoning,
                            content: {
                                Text(reasoning)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.top, 2)
                            },
                            label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 10))
                                    Text(message.isStreaming ? "正在思考中…" : "已思考过程")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary)
                            }
                        )
                        .padding(.horizontal, 4)
                    }

                    // 打字中打字指示器
                    if message.isStreaming && !message.content.isEmpty {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("千语正在回信……")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }

            if isUser {
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
