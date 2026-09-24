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
    @State private var showSuccessNotice: Bool = false
    @State private var importedCount: Int = 0

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
            .alert("导入成功！", isPresented: $showSuccessNotice) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("千语已为你导入 \(importedCount) 门每周课程，上课前会按时提醒你哦！冲冲冲！")
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
            name: course.name
        )
        let isConflict = !isDup && viewModel.hasTimeConflict(
            weekday: course.weekday,
            startTotalMinutes: course.startTotalMinutes,
            endTotalMinutes: course.endTotalMinutes,
            name: course.name
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

                    if course.occurrencesCount > 1 {
                        Text("\(course.occurrencesCount)周次")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }

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
                        Text("当前课表中已有同名同时间课程（追加导入将自动跳过重复项）")
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
        viewModel.importCourses(items, mode: importMode)

        importedCount = items.count
        showSuccessNotice = true
    }
}
