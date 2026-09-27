//
//  ImportCoursesPreviewSheet.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct ImportCoursesPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var viewModel: CourseScheduleViewModel
    public let parseResult: ICSParseResult

    @State private var courses: [ParsedCourse] = []
    @State private var importMode: CourseScheduleViewModel.CourseImportMode = .append
    @State private var defaultRemindMinutes: Int = 15
    @State private var syncSemesterStartDate: Bool = true
    @State private var showSuccessNotice: Bool = false
    @State private var importSummary = CourseScheduleViewModel.CourseImportSummary()

    private let reminderOptions = [5, 10, 15, 20, 30, 45, 60]

    public init(viewModel: CourseScheduleViewModel, parseResult: ICSParseResult) {
        self.viewModel = viewModel
        self.parseResult = parseResult
        self._courses = State(initialValue: parseResult.courses)
    }

    private var selectedCount: Int {
        courses.filter { $0.isSelected }.count
    }

    private var isAllSelected: Bool {
        !courses.isEmpty && courses.allSatisfy { $0.isSelected }
    }

    private var importResultMessage: String {
        guard importSummary.didSave else {
            return "课程表没有保存成功，请重试。"
        }
        if importSummary.addedCount == 0 && importSummary.mergedCount == 0 {
            return "所选 \(importSummary.unchangedCount) 门课程已存在且周次没有变化，没有新增课程。"
        }
        var details: [String] = []
        if importSummary.addedCount > 0 {
            details.append("新增 \(importSummary.addedCount) 门课程")
        }
        if importSummary.mergedCount > 0 {
            details.append("合并更新 \(importSummary.mergedCount) 门已有课程的周次")
        }
        return "千语\(details.joined(separator: "，"))。未变化的重复项 \(importSummary.unchangedCount) 门未重复添加。"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 顶部概要卡片
                    summaryCard

                    // 2. 导入策略与提醒设置卡片
                    settingsCard

                    // 3. 课程列表与批量选择
                    courseListSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.secondary.opacity(0.04).ignoresSafeArea())
            .navigationTitle("导入课程表 (.ics)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        executeImport()
                    } label: {
                        Text("导入 (\(selectedCount))")
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedCount == 0)
                }
            }
            .alert(importSummary.didSave ? "导入完成" : "导入失败", isPresented: $showSuccessNotice) {
                if importSummary.didSave {
                    Button("确定") { dismiss() }
                } else {
                    Button("继续编辑", role: .cancel) {}
                }
            } message: {
                Text(importResultMessage)
            }
        }
    }

    // MARK: - 顶部概要卡片
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(parseResult.calendarName ?? "日历课表文件")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)

                    Text("成功解析出 \(parseResult.uniqueCoursesCount) 门规律周课 (扫描 \(parseResult.totalEventsCount) 场日程)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if let semDesc = parseResult.detectedSemesterStartDescription {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("自动识别学期开学：\(semDesc) (第 1 周周一)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.top, 2)
            }

            if parseResult.skippedAllDayEventsCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("已自动过滤 \(parseResult.skippedAllDayEventsCount) 个全天非上课事件 (如节假日或校历)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.5, opacity: 0.08))
        )
    }

    // MARK: - 导入策略与提醒设置
    private var settingsCard: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("导入模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("导入模式", selection: $importMode) {
                    ForEach(CourseScheduleViewModel.CourseImportMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            HStack {
                Label("默认提前提醒", systemImage: "bell.badge")
                    .font(.system(size: 14))

                Spacer()

                Picker("提醒时间", selection: $defaultRemindMinutes) {
                    ForEach(reminderOptions, id: \.self) { mins in
                        Text("提前 \(mins) 分钟").tag(mins)
                    }
                }
                .pickerStyle(.menu)
            }

            if parseResult.detectedSemesterStartDate != nil {
                Divider()

                Toggle(isOn: $syncSemesterStartDate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动校准开学日期")
                            .font(.system(size: 14))
                        Text("将开学第一周对齐到 \(parseResult.detectedSemesterStartDescription ?? "")，确保单双周和本周课表精准计算。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.5, opacity: 0.08))
        )
    }

    // MARK: - 课程列表区域
    private var courseListSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("解析到的课程清单 (\(selectedCount)/\(courses.count))")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                Button {
                    let target = !isAllSelected
                    for i in courses.indices {
                        courses[i].isSelected = target
                    }
                } label: {
                    Text(isAllSelected ? "取消全选" : "全选")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            LazyVStack(spacing: 10) {
                ForEach(courses.indices, id: \.self) { index in
                    courseRow(index: index)
                }
            }
        }
    }

    // MARK: - 单行课程卡片
    private func courseRow(index: Int) -> some View {
        let course = courses[index]
        let isDup = viewModel.isDuplicate(
            weekday: course.weekday,
            startTotalMinutes: course.startTotalMinutes,
            endTotalMinutes: course.endTotalMinutes,
            name: course.name,
            classroom: course.classroom,
            teacher: course.teacher
        )
        let isConflict = !isDup && viewModel.hasTimeConflict(
            weekday: course.weekday,
            startTotalMinutes: course.startTotalMinutes,
            endTotalMinutes: course.endTotalMinutes,
            name: course.name,
            activeWeeks: course.activeWeeks.isEmpty
                ? Set((course.startWeek...course.endWeek).filter { week in
                    switch course.weekModeRaw {
                    case "oddOnly": return week % 2 == 1
                    case "evenOnly": return week % 2 == 0
                    default: return true
                    }
                })
                : course.activeWeeks
        )

        return HStack(spacing: 12) {
            // 选择框
            Button {
                courses[index].isSelected.toggle()
            } label: {
                Image(systemName: course.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(course.isSelected ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            // 颜色装饰条
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: course.colorHex))
                .frame(width: 4, height: 46)

            // 课程核心信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(course.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(course.weekModeDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Text(course.weekdayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(course.formattedTime)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)

                    if !course.classroom.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                            Text(course.classroom)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }

                    if !course.teacher.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.system(size: 11))
                            Text(course.teacher)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                // 重复或冲突提示
                if isDup && importMode == .append {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("当前课表中已有同名同时间课程（追加导入会合并周次；无变化的重复项不会重复添加）")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.orange)
                    .padding(.top, 2)
                } else if isConflict {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 10))
                        Text("注意：与现有其它课程时间段重叠")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.5, opacity: 0.08))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            courses[index].isSelected.toggle()
        }
    }

    // MARK: - 执行导入
    private func executeImport() {
        let selectedCourses = courses.filter { $0.isSelected }
        guard !selectedCourses.isEmpty else { return }

        let items = selectedCourses.map { $0.toCourseItem(remindBeforeMinutes: defaultRemindMinutes) }
        importSummary = viewModel.importCourses(items, mode: importMode)
        if importSummary.didSave, syncSemesterStartDate,
           let detectedStart = parseResult.detectedSemesterStartDate {
            AppSettings.shared.semesterStartDate = detectedStart
            viewModel.selectedWeek = AppSettings.shared.currentWeekNumber()
            viewModel.updateWidgetSnapshot()
            CourseReminderService.shared.syncAllCourseReminders(courses: viewModel.courses)
        }
        showSuccessNotice = true
    }
}
