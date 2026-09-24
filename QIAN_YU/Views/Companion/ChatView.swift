//
//  ChatView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData

public struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @Environment(\.modelContext) private var modelContext
    public let scheduleViewModel: CourseScheduleViewModel

    public init(scheduleViewModel: CourseScheduleViewModel) {
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
                        "千语，我下一节课快到了，帮我提个醒、打打气呗！",
                        upcomingCourseHint: scheduleViewModel.nextCourseSummary
                    )
                }
            )

            // 3. 消息气泡流
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
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
                                    Text(viewModel.isHistoryExpanded ? "收起往期历史记录" : "展开往期历史记录 (\(viewModel.historyMessages.count) 条)")
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
                                ForEach(viewModel.historyMessages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .onChange(of: viewModel.currentSessionMessages.last?.content) { _, _ in
                    if let lastId = viewModel.currentSessionMessages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 4. 快捷闲聊胶囊标签
            QuickActionChipsView { prompt in
                viewModel.sendQuickPrompt(
                    prompt,
                    upcomingCourseHint: scheduleViewModel.nextCourseSummary
                )
            }

            // 5. 底部输入栏
            HStack(spacing: 10) {
                TextField("找千语唠嗑或问课表……", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.sendMessage(upcomingCourseHint: scheduleViewModel.nextCourseSummary)
                    }

                Button {
                    viewModel.sendMessage(upcomingCourseHint: scheduleViewModel.nextCourseSummary)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            (viewModel.inputText.isEmpty || viewModel.isGenerating)
                                ? Color.gray.opacity(0.4)
                                : Color.orange
                        )
                        .clipShape(Circle())
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("千语伴行")
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
