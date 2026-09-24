//
//  CourseScheduleViewModel.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
@MainActor
public final class CourseScheduleViewModel {
    public var courses: [CourseItem] = []
    public var selectedWeekday: Int = 1 // 1=周一 ... 7=周日
    public var isShowingAddSheet: Bool = false
    public var isShowingAICourseImportSheet: Bool = false
    public var isShowingImportPicker: Bool = false
    public var isShowingImportPreview: Bool = false
    public var currentImportResult: ICSParseResult? = nil
    public var importErrorMessage: String? = nil
    public var isShowingImportErrorAlert: Bool = false

    /// 是否只看本教学周生效的课程 (单双周与起止周过滤)
    public var isFilteringCurrentWeek: Bool = false
    /// 系统日历同步中状态与提示
    public var isSyncingCalendar: Bool = false
    public var calendarSyncAlertMessage: String? = nil
    public var isShowingCalendarAlert: Bool = false

    private var modelContext: ModelContext?

    public init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        self.setInitialWeekday()
    }

    public func setContext(_ context: ModelContext) {
        self.modelContext = context
        self.loadCourses()
    }

    private func setInitialWeekday() {
        let weekdayIndex = Calendar.current.component(.weekday, from: Date())
        // Apple Calendar: 1=Sun, 2=Mon...7=Sat -> 转为 1=周一...7=周日
        self.selectedWeekday = weekdayIndex == 1 ? 7 : weekdayIndex - 1
    }

    public func loadCourses() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<CourseItem>(sortBy: [
            SortDescriptor(\.weekday, order: .forward),
            SortDescriptor(\.startHour, order: .forward),
            SortDescriptor(\.startMinute, order: .forward)
        ])
        if let saved = try? context.fetch(descriptor) {
            self.courses = saved
        }

        // 如果全新无课表，预设示例课程供体验
        if courses.isEmpty {
            createSampleCourses(in: context)
        }

        CourseReminderService.shared.syncAllCourseReminders(courses: courses)
        updateWidgetSnapshot()
    }

    private func createSampleCourses(in context: ModelContext) {
        let sample1 = CourseItem(
            name: "高等数学 (上)",
            classroom: "正心楼 312",
            teacher: "张教授",
            weekday: 1, // 周一
            startHour: 8,
            startMinute: 30,
            endHour: 10,
            endMinute: 5,
            remindBeforeMinutes: 15,
            colorHex: "#FF9500"
        )
        let sample2 = CourseItem(
            name: "数据结构与算法",
            classroom: "实验楼 A408",
            teacher: "李老师",
            weekday: 1, // 周一
            startHour: 14,
            startMinute: 0,
            endHour: 15,
            endMinute: 35,
            remindBeforeMinutes: 20,
            colorHex: "#34C759"
        )
        let sample3 = CourseItem(
            name: "剑术体能与形体",
            classroom: "北区风雨操场",
            teacher: "陈教练",
            weekday: 3, // 周三
            startHour: 10,
            startMinute: 15,
            endHour: 11,
            endMinute: 50,
            remindBeforeMinutes: 15,
            colorHex: "#AF52DE"
        )

        courses = [sample1, sample2, sample3]
        context.insert(sample1)
        context.insert(sample2)
        context.insert(sample3)
        try? context.save()
    }

    /// 获取特定星期的课程 (可选是否仅看当前教学周生效的课程)
    public func coursesForWeekday(_ day: Int, onlyCurrentWeek: Bool? = nil) -> [CourseItem] {
        let shouldFilter = onlyCurrentWeek ?? isFilteringCurrentWeek
        let currentWeek = AppSettings.shared.currentWeekNumber()

        return courses.filter { course in
            guard course.weekday == day else { return false }
            if shouldFilter {
                return course.isActive(inWeek: currentWeek)
            }
            return true
        }
        .sorted { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 今天的所有课程（自动根据当前教学周单双周与周数过滤）
    public var todayCourses: [CourseItem] {
        let weekdayIndex = Calendar.current.component(.weekday, from: Date())
        let todayDay = weekdayIndex == 1 ? 7 : weekdayIndex - 1
        let currentWeek = AppSettings.shared.currentWeekNumber()
        return courses.filter { $0.weekday == todayDay && $0.isActive(inWeek: currentWeek) }
            .sorted { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 今天的下一门即将到来的课程
    public var nextUpcomingCourse: CourseItem? {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())
        let currentMinutes = currentHour * 60 + currentMinute

        // 筛选尚未结束的课程
        return todayCourses
            .filter { $0.isEnabled && $0.endTotalMinutes >= currentMinutes }
            .min { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 下一门课程的一句话摘要（传给 PersonaEngine）
    public var nextCourseSummary: String? {
        guard let next = nextUpcomingCourse else { return nil }
        let currentMinutes = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        let diff = next.startTotalMinutes - currentMinutes

        if diff > 0 {
            return "距离下节【\(next.name)】(在\(next.classroom.isEmpty ? "教室" : next.classroom))还有约\(diff)分钟"
        } else {
            return "【\(next.name)】当前正在上课中 (在\(next.classroom.isEmpty ? "教室" : next.classroom))"
        }
    }

    public func addCourse(_ course: CourseItem) {
        guard let context = modelContext else { return }
        context.insert(course)
        try? context.save()
        loadCourses()
    }

    public func deleteCourse(_ course: CourseItem) {
        guard let context = modelContext else { return }
        CourseReminderService.shared.cancelCourseReminder(course: course)
        context.delete(course)
        try? context.save()
        loadCourses()
    }

    public func toggleCourseEnabled(_ course: CourseItem) {
        course.isEnabled.toggle()
        try? modelContext?.save()
        CourseReminderService.shared.syncAllCourseReminders(courses: courses)
        updateWidgetSnapshot()
    }

    // MARK: - .ics 课表导入支持

    public enum CourseImportMode: String, CaseIterable, Identifiable {
        case append = "追加到现有课表"
        case replace = "清空并覆盖现有课表"

        public var id: String { rawValue }
    }

    /// 检查某节课是否与已有课程完全相同 (星期 + 时间 + 名称)
    public func isDuplicate(weekday: Int, startTotalMinutes: Int, endTotalMinutes: Int, name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return courses.contains { course in
            course.weekday == weekday &&
            course.startTotalMinutes == startTotalMinutes &&
            course.endTotalMinutes == endTotalMinutes &&
            course.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName
        }
    }

    /// 检查某节课是否与已有课程存在时间段重叠冲突
    public func hasTimeConflict(weekday: Int, startTotalMinutes: Int, endTotalMinutes: Int, name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return courses.contains { course in
            guard course.weekday == weekday else { return false }
            if course.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName {
                return false
            }
            let overlapStart = max(course.startTotalMinutes, startTotalMinutes)
            let overlapEnd = min(course.endTotalMinutes, endTotalMinutes)
            return overlapStart < overlapEnd
        }
    }

    /// 批量导入课程
    public func importCourses(_ newCourses: [CourseItem], mode: CourseImportMode = .append) {
        guard let context = modelContext else { return }

        if mode == .replace {
            for course in courses {
                CourseReminderService.shared.cancelCourseReminder(course: course)
                context.delete(course)
            }
            courses.removeAll()
        }

        for course in newCourses {
            // 如果是追加模式，避免完全相同重复插入
            if mode == .append && isDuplicate(
                weekday: course.weekday,
                startTotalMinutes: course.startTotalMinutes,
                endTotalMinutes: course.endTotalMinutes,
                name: course.name
            ) {
                continue
            }
            context.insert(course)
        }

        try? context.save()
        loadCourses()
    }

    /// 处理文档选择器返回的 .ics 文件
    public func handleFileImportResult(_ result: Result<URL, Error>) {
        do {
            let selectedURL = try result.get()
            let isAccessing = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: selectedURL)
            let parseResult = try ICSParserService.shared.parse(data: data)

            if parseResult.courses.isEmpty {
                self.importErrorMessage = "该日历文件中未找到任何有效的上课日程。"
                self.isShowingImportErrorAlert = true
            } else {
                self.currentImportResult = parseResult
                self.isShowingImportPreview = true
            }
        } catch {
            self.importErrorMessage = error.localizedDescription
            self.isShowingImportErrorAlert = true
        }
    }

    // MARK: - 系统日历同步支持

    /// 一键将当前课表同步至 Apple 系统日历 (EventKit)
    public func syncToCalendar() {
        guard !courses.isEmpty else {
            calendarSyncAlertMessage = "当前课表暂无课程，请先添加或导入课程后再同步。"
            isShowingCalendarAlert = true
            return
        }

        isSyncingCalendar = true
        Task {
            do {
                let count = try await CalendarSyncService.shared.syncCoursesToSystemCalendar(
                    courses: courses,
                    semesterStartDate: AppSettings.shared.semesterStartDate
                )
                self.isSyncingCalendar = false
                self.calendarSyncAlertMessage = "🎉 已成功同步 \(count) 门课程至 Apple 系统日历！\n可在系统「日历」App 中查看「QIAN YU 课表」专项目录。"
                self.isShowingCalendarAlert = true
            } catch {
                self.isSyncingCalendar = false
                self.calendarSyncAlertMessage = "系统日历同步失败：\(error.localizedDescription)"
                self.isShowingCalendarAlert = true
            }
        }
    }

    // MARK: - 小组件数据快照同步
    public func updateWidgetSnapshot() {
        let appGroupID = "group.com.qianyu.companion"
        let userDefaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard

        if let course = self.nextUpcomingCourse {
            userDefaults.set(course.name, forKey: "widget_course_name")
            userDefaults.set(course.classroom.isEmpty ? "教室未指定" : course.classroom, forKey: "widget_classroom")
            userDefaults.set(course.formattedTime, forKey: "widget_time_string")
            userDefaults.set(course.teacher, forKey: "widget_teacher")
            userDefaults.set(AppSettings.shared.currentWeekDisplay, forKey: "widget_week_info")
            userDefaults.set(false, forKey: "widget_is_no_class")
        } else {
            userDefaults.set("今日已无课", forKey: "widget_course_name")
            userDefaults.set("", forKey: "widget_classroom")
            userDefaults.set("", forKey: "widget_time_string")
            userDefaults.set("", forKey: "widget_teacher")
            userDefaults.set(AppSettings.shared.currentWeekDisplay, forKey: "widget_week_info")
            userDefaults.set(true, forKey: "widget_is_no_class")
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
