//
//  AICourseImportSheet.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct AICourseImportSheet: View {
    @Bindable public var viewModel: CourseScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isParsing: Bool = false
    @State private var parsedCourses: [ParsedCourseDTO] = []
    @State private var importMode: CourseScheduleViewModel.CourseImportMode = .append
    @State private var statusMessage: String? = nil

    private let samplePrompt = """
    周一 08:30-10:05 高等数学 正心楼312 张教授
    周一 14:00-15:35 数据结构 实验楼A408 李老师
    周三 10:15-11:50 剑术体能操 风雨操场 陈教练
    周五 09:00-11:30 计算机网络 (单周) 教四201
    """

    public init(viewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 顶部指引卡片
                    HStack(spacing: 12) {
                        Image("QianyuAvatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.orange.opacity(0.3), lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("千语 AI 智能排课")
                                .font(.system(size: 15, weight: .bold))
                            Text("把学校教务系统课表文本粘贴在下面，我来帮你全自动拆解成课程！")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // 2. 文本输入区
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("课表文本")
                                .font(.system(size: 13, weight: .semibold))

                            Spacer()

                            Button("填入示例") {
                                inputText = samplePrompt
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        }

                        TextEditor(text: $inputText)
                            .font(.system(size: 13))
                            .frame(minHeight: 110, maxHeight: 150)
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 3. 识别解析触发按钮
                    Button {
                        startParsing()
                    } label: {
                        HStack(spacing: 6) {
                            if isParsing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("千语正在深入琢磨排课……")
                            } else {
                                Image(systemName: "sparkles")
                                Text("让千语解析课表")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing ? Color.gray.opacity(0.4) : Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
                    .buttonStyle(.plain)

                    if let status = statusMessage {
                        Text(status)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // 4. 解析结果展示
                    if !parsedCourses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("成功识别出 \(parsedCourses.count) 门课程")
                                    .font(.system(size: 14, weight: .bold))

                                Spacer()

                                Picker("导入方式", selection: $importMode) {
                                    ForEach(CourseScheduleViewModel.CourseImportMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 220)
                            }

                            ForEach(parsedCourses) { course in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.name)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("\(weekdayName(course.weekday)) \(String(format: "%02d:%02d", course.startHour, course.startMinute)) - \(String(format: "%02d:%02d", course.endHour, course.endMinute)) @ \(course.classroom.isEmpty ? "待定教室" : course.classroom)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(weekRuleBadge(course.weekModeRaw))
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // 确认导入按钮
                            Button {
                                let newItems = parsedCourses.map { $0.toCourseItem() }
                                viewModel.importCourses(newItems, mode: importMode)
                                dismiss()
                            } label: {
                                Text("全部确认并导入课表")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("AI 智能识别排课")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 460)
    }

    private func startParsing() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isParsing = true
        statusMessage = nil
        Task {
            let res = try? await AICourseParserService.shared.parseWithAI(text: text)
            self.parsedCourses = res ?? []
            self.isParsing = false
            if self.parsedCourses.isEmpty {
                self.statusMessage = "未能从文本中识别出有效课程日程，请检查格式或包含星期与时间（例如：周一 08:30-10:05 高等数学）。"
            }
        }
    }

    private func weekdayName(_ day: Int) -> String {
        switch day {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        case 7: return "周日"
        default: return "周一"
        }
    }

    private func weekRuleBadge(_ mode: String) -> String {
        switch mode {
        case "oddOnly": return "单周"
        case "evenOnly": return "双周"
        default: return "全周"
        }
    }
}
