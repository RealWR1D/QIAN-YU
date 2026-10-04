//
//  ChatView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData

public struct ChatView: View {
    @Bindable public var viewModel: ChatViewModel
    @State private var isChatVisible = false
    @State private var followsLatest = true
    @State private var viewportHeight: CGFloat = 0
    @State private var geometryContent = ""
    @Environment(\.modelContext) private var modelContext
    public let scheduleViewModel: CourseScheduleViewModel

    public init(viewModel: ChatViewModel, scheduleViewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
        self.scheduleViewModel = scheduleViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部千语角色与状态展示
            CompanionHeaderView(currentStatus: $viewModel.currentStatus)

            // 2. 今日下一节课常驻动态横幅
            NextClassBannerView(
                nextCourse: scheduleViewModel.nextUpcomingCourse,
                onAskQianyu: {
                    viewModel.sendQuickPrompt(
                        String(localized: "千语，我下一节课快到了，帮我提个醒、打打气呗！"),
                        upcomingCourseHint: scheduleViewModel.nextCourseSummary, scheduleContext: scheduleViewModel.chatScheduleContext(for: "下一节课")
                    )
                }
            )

            // 3. 消息气泡流
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        // 往期历史记录折叠区（进入 App 时默认收起）
                        if !viewModel.historyMessages.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.isHistoryExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isHistoryExpanded ? "chevron.up.circle.fill" : "clock.arrow.circlepath")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(viewModel.isHistoryExpanded ? "收起往期历史记录" : "展开往期历史记录 (\(viewModel.historyCount) 条)")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)

                            if viewModel.isHistoryExpanded {
                                if viewModel.hasMoreHistory {
                                    Button("加载更早的消息") { viewModel.loadMoreHistory() }
                                }
                                LazyVStack(spacing: 14) {
                                ForEach(viewModel.historyMessages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }

                                }
                                HStack(spacing: 10) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 1)
                                    Text("以上为往期历史对话")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 6)
                            }
                        }

                        // 当前会话消息流
                        ForEach(viewModel.currentSessionMessages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id("conversationBottom")
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: ChatBottomPosition.self, value: geometry.frame(in: .named("chatScroll")).maxY)
                            })
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .coordinateSpace(name: "chatScroll")
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ChatViewportHeight.self, value: geometry.size.height)
                })
                .onPreferenceChange(ChatViewportHeight.self) { viewportHeight = $0 }
                .onPreferenceChange(ChatBottomPosition.self) { bottom in
                    guard viewportHeight > 0 else { return }
                    let content = viewModel.currentSessionMessages.last?.content ?? ""
                    if content != geometryContent { geometryContent = content; return }
                    followsLatest = bottom <= viewportHeight + 80
                }
                .overlay(alignment: .bottomTrailing) {
                    if !followsLatest {
                        Button("回到最新消息") { followsLatest = true; proxy.scrollTo("conversationBottom", anchor: .bottom) }
                            .buttonStyle(.borderedProminent).padding(12)
                    }
                }
                .onChange(of: viewModel.renderRevision) { _, _ in
                    guard isChatVisible && followsLatest else { return }
                    proxy.scrollTo("conversationBottom", anchor: .bottom)
                }
                .onChange(of: viewModel.currentSessionMessages.count) { _, _ in
                    followsLatest = true
                    guard isChatVisible else { return }
                    proxy.scrollTo("conversationBottom", anchor: .bottom)
                }
                .task {
                    viewModel.setVisible(true)
                    isChatVisible = true
                    // Restore after the transcript has laid out, including offscreen updates.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo("conversationBottom", anchor: .bottom)
                }
                .onDisappear { isChatVisible = false; viewModel.setVisible(false) }
            }

            if let error = viewModel.saveErrorMessage {
                HStack {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("重试保存") { viewModel.persistMessages() }
                }.padding(8)
            }
            if let last = viewModel.currentSessionMessages.last, last.generationError != nil, !viewModel.isGenerating {
                Button("重试回复") { viewModel.retryLastResponse() }.padding(6)
            }
            Divider()

            // 4. 快捷闲聊胶囊标签
            QuickActionChipsView { prompt in
                viewModel.sendQuickPrompt(
                    prompt,
                    upcomingCourseHint: scheduleViewModel.nextCourseSummary, scheduleContext: scheduleViewModel.chatScheduleContext(for: prompt)
                )
            }

            // 5. 底部输入栏
            HStack(spacing: 10) {
                TextField("找千语唠嗑或问课表……", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.sendMessage(upcomingCourseHint: scheduleViewModel.nextCourseSummary, scheduleContext: scheduleViewModel.chatScheduleContext(for: viewModel.inputText))
                    }

                Button {
                    if viewModel.isGenerating { viewModel.cancelGeneration() }
                    else { viewModel.sendMessage(upcomingCourseHint: scheduleViewModel.nextCourseSummary, scheduleContext: scheduleViewModel.chatScheduleContext(for: viewModel.inputText)) }
                } label: {
                    Image(systemName: viewModel.isGenerating ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            (viewModel.inputText.isEmpty && !viewModel.isGenerating)
                                ? Color.gray.opacity(0.4)
                                : Color.orange
                        )
                        .clipShape(Circle())
                }
                .disabled(viewModel.inputText.isEmpty && !viewModel.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("QIAN YU")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(role: .destructive) {
                        viewModel.clearAllMessages()
                    } label: {
                        Label("清空对话记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            viewModel.setContext(modelContext)
        }
    }
}

private struct ChatBottomPosition: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct ChatViewportHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
