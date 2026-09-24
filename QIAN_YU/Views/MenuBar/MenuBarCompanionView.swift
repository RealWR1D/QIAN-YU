//
//  MenuBarCompanionView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit

public struct MenuBarCompanionView: View {
    @State private var quickText: String = ""
    @State private var latestReply: String = "在呢在呢！管理员，今天想带我去哪儿练剑，或者有啥课要上？"
    @State private var currentStatus: String = QianYuDialogueCorpus.randomStatus()
    public let scheduleViewModel: CourseScheduleViewModel

    public init(scheduleViewModel: CourseScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部状态栏
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image("QianyuAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("陈千语 · 随行状态")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)

                    Text(currentStatus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    currentStatus = QianYuDialogueCorpus.randomStatus()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 下一门课提醒卡片
            if let course = scheduleViewModel.nextUpcomingCourse {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("下节课：\(course.name)")
                            .font(.system(size: 12, weight: .semibold))

                        Text("\(course.formattedTime) @ \(course.classroom.isEmpty ? "待定" : course.classroom)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let mins = course.minutesUntilClassToday() {
                        Text(mins == 0 ? "上课中" : "\(mins)分后")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 快捷互动气泡
            VStack(alignment: .leading, spacing: 4) {
                Text(latestReply)
                    .font(.system(size: 12))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 迷你输入框
            HStack(spacing: 6) {
                TextField("跟千语说句话……", text: $quickText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        sendQuickMessage()
                    }

                Button {
                    sendQuickMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .disabled(quickText.isEmpty)
                .buttonStyle(.plain)
            }

            Divider()

            // 底部操作
            HStack {
                Button("打开主窗口") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .font(.system(size: 12))

                Spacer()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func sendQuickMessage() {
        let text = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        quickText = ""

        latestReply = QianYuDialogueCorpus.matchReply(
            for: text,
            userName: AppSettings.shared.userName,
            nextCourseSummary: scheduleViewModel.nextCourseSummary
        )
    }
}
#endif
