//
//  CourseScheduleView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct CourseScheduleView: View {
    @Bindable public var viewModel: CourseScheduleViewModel
    @Environment(\.modelContext) private var modelContext

    private let weekdays = [
        (1, "周一"), (2, "周二"), (3, "周三"), (4, "周四"),
        (5, "周五"), (6, "周六"), (7, "周日")
    ]

    public init(viewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
    }

    private var currentSystemWeekday: Int {
        let weekdayIndex = Calendar.current.component(.weekday, from: Date())
        return weekdayIndex == 1 ? 7 : weekdayIndex - 1
    }

    private var icsContentTypes: [UTType] {
        var types: [UTType] = []
        if let ics = UTType(filenameExtension: "ics") {
            types.append(ics)
        }
        if let cal = UTType("com.apple.ical.ics") {
            types.append(cal)
        }
        return types.isEmpty ? [.item] : types
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 0. 学期教学周横幅与视图过滤
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))

                    Text(AppSettings.shared.currentWeekDisplay)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Picker("", selection: $viewModel.isFilteringCurrentWeek) {
                    Text("全学期").tag(false)
                    Text("仅本周").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // 1. 星期选择器横条
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.0) { item in
                    let isSelected = viewModel.selectedWeekday == item.0
                    let isToday = currentSystemWeekday == item.0

                    Button {
                        viewModel.selectedWeekday = item.0
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.1)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : (isToday ? .orange : .primary))

                            if isToday {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.orange)
                                    .frame(width: 4, height: 4)
                            } else {
                                Spacer().frame(height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.orange : Color.secondary.opacity(0.08)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // 2. 课程卡片列表
            let coursesForDay = viewModel.coursesForWeekday(viewModel.selectedWeekday)

            if coursesForDay.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                    }

                    Text("今天没有安排课程哦！")
                        .font(.system(size: 16, weight: .semibold))

                    Text("「走走走！正好带我去后山转转，比划两招！」")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 10) {
                        Button {
                            viewModel.isShowingAICourseImportSheet = true
                        } label: {
                            Label("AI 智能识别排课", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: 240)
                                .padding(.vertical, 10)
                                .background(LinearGradient(colors: [.orange, .purple], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            Button {
                                viewModel.isShowingImportPicker = true
                            } label: {
                                Label("导入 .ics 课表", systemImage: "calendar.badge.plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.isShowingAddSheet = true
                            } label: {
                                Label("手动加课", systemImage: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coursesForDay) { course in
                            CourseCardView(
                                course: course,
                                onToggle: {
                                    viewModel.toggleCourseEnabled(course)
                                },
                                onDelete: {
                                    viewModel.deleteCourse(course)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .navigationTitle("上课日程表")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Label("手动添加课程", systemImage: "plus")
                    }

                    Button {
                        viewModel.isShowingAICourseImportSheet = true
                    } label: {
                        Label("AI 智能排课 / 导课", systemImage: "sparkles")
                    }

                    Button {
                        viewModel.isShowingImportPicker = true
                    } label: {
                        Label("导入 .ics 日历课表", systemImage: "calendar.badge.plus")
                    }

                    Divider()

                    Button {
                        viewModel.syncToCalendar()
                    } label: {
                        Label("同步至 Apple 系统日历", systemImage: "arrow.triangle.2.circlepath.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddCourseSheet(initialWeekday: viewModel.selectedWeekday) { newCourse in
                viewModel.addCourse(newCourse)
            }
        }
        .sheet(isPresented: $viewModel.isShowingAICourseImportSheet) {
            AICourseImportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingImportPreview) {
            if let result = viewModel.currentImportResult {
                ImportCoursesPreviewSheet(viewModel: viewModel, parseResult: result)
            }
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImportPicker,
            allowedContentTypes: icsContentTypes
        ) { result in
            viewModel.handleFileImportResult(result)
        }
        .alert("导入提示", isPresented: $viewModel.isShowingImportErrorAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.importErrorMessage ?? "未能成功解析日历文件")
        }
        .alert("系统日历同步", isPresented: $viewModel.isShowingCalendarAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.calendarSyncAlertMessage ?? "")
        }
        .overlay {
            if viewModel.isSyncingCalendar {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在同步至系统日历…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Material.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .task {
            viewModel.setContext(modelContext)
        }
    }
}
