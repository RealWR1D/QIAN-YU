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
    private static let sampleCoursesSeededKey = "qianyu.sampleCoursesSeeded.v1"

    public var courses: [CourseItem] = []
    public var selectedWeekday: Int = 1 // 1=周一 ... 7=周日
    public var isShowingAddSheet: Bool = false
    public var isShowingImportPicker: Bool = false
    public var isShowingImportPreview: Bool = false
    public var currentImportResult: ICSParseResult? = nil
    /// 外部文件唤起应用时，即使尚未显示课程页，也能恢复导航和导入预览。
    public private(set) var externalImportRequestID: UUID? = nil
    public private(set) var importPresentationID = UUID()
    public var importErrorMessage: String? = nil
    public var isShowingImportErrorAlert: Bool = false

    /// 是否只看选定教学周生效的课程 (单双周与起止周过滤)
    public var isFilteringCurrentWeek: Bool = false
    /// 当前用户选定查看的教学周 (默认对齐当前系统计算教学周)
    public var selectedWeek: Int = 1
    /// 系统日历同步中状态与提示
    public var isSyncingCalendar: Bool = false
    public var calendarSyncAlertMessage: String? = nil
    public var isShowingCalendarAlert: Bool = false
    public var courseOperationErrorMessage: String? = nil
    public var isShowingCourseOperationError: Bool = false

    private var modelContext: ModelContext?

    public init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        self.setInitialWeekday()
        self.selectedWeek = AppSettings.shared.currentWeekNumber()
    }

    public func setContext(_ context: ModelContext) {
        self.modelContext = context
        self.selectedWeek = AppSettings.shared.currentWeekNumber()
        self.loadCourses()
    }

    private func setInitialWeekday() {
        self.selectedWeekday = CourseTimeRules.weekday(on: Date())
    }

    public func loadCourses() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<CourseItem>(sortBy: [
            SortDescriptor(\.weekday, order: .forward),
            SortDescriptor(\.startHour, order: .forward),
            SortDescriptor(\.startMinute, order: .forward)
        ])
        let saved: [CourseItem]
        do {
            saved = try context.fetch(descriptor)
        } catch {
            NSLog("读取课程表失败，跳过示例课程初始化：%@", error.localizedDescription)
            return
        }
        self.courses = saved

        // 只在首次启动且数据库为空时播种示例课程。先前安装已有真实课程的用户
        // 也会被记录为已完成初始化，以免以后删空课表时重新灌入示例数据。
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.sampleCoursesSeededKey) {
            if saved.isEmpty {
                do {
                    try createSampleCourses(in: context)
                    defaults.set(true, forKey: Self.sampleCoursesSeededKey)
                } catch {
                    NSLog("初始化示例课程失败：%@", error.localizedDescription)
                }
            } else {
                defaults.set(true, forKey: Self.sampleCoursesSeededKey)
            }
        }

        CourseReminderService.shared.syncAllCourseReminders(courses: courses)
        updateWidgetSnapshot()
    }

    private func createSampleCourses(in context: ModelContext) throws {
        let sample1 = CourseItem(
            name: String(localized: "高等数学 (上)"),
            classroom: String(localized: "正心楼 312"),
            teacher: String(localized: "张教授"),
            weekday: 1, // 周一
            startHour: 8,
            startMinute: 30,
            endHour: 10,
            endMinute: 5,
            remindBeforeMinutes: 15,
            colorHex: "#FF9500"
        )
        let sample2 = CourseItem(
            name: String(localized: "数据结构与算法"),
            classroom: String(localized: "实验楼 A408"),
            teacher: String(localized: "李老师"),
            weekday: 1, // 周一
            startHour: 14,
            startMinute: 0,
            endHour: 15,
            endMinute: 35,
            remindBeforeMinutes: 20,
            colorHex: "#34C759"
        )
        let sample3 = CourseItem(
            name: String(localized: "剑术体能与形体"),
            classroom: String(localized: "北区风雨操场"),
            teacher: String(localized: "陈教练"),
            weekday: 3, // 周三
            startHour: 10,
            startMinute: 15,
            endHour: 11,
            endMinute: 50,
            remindBeforeMinutes: 15,
            colorHex: "#AF52DE"
        )

        let samples = [sample1, sample2, sample3]
        for sample in samples {
            context.insert(sample)
        }

        do {
            try context.save()
            courses = samples
        } catch {
            for sample in samples {
                context.delete(sample)
            }
            throw error
        }
    }

    /// 获取特定星期的课程 (可选是否仅看选定教学周生效的课程)
    public func coursesForWeekday(_ day: Int, week: Int? = nil, onlyCurrentWeek: Bool? = nil) -> [CourseItem] {
        let shouldFilter = onlyCurrentWeek ?? isFilteringCurrentWeek
        let targetWeek = week ?? selectedWeek

        return courses.filter { course in
            guard course.weekday == day else { return false }
            if shouldFilter {
                return course.isActive(inWeek: targetWeek)
            }
            return true
        }
        .sorted { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 今天的所有课程（自动根据当前教学周单双周与周数过滤）
    public var todayCourses: [CourseItem] {
        let now = Date()
        return courses.filter { $0.isScheduledForToday(on: now) }
            .sorted { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 今天的下一门即将到来的课程
    public var nextUpcomingCourse: CourseItem? {
        let now = Date()
        return todayCourses.filter { CourseTimeRules.hasNotEnded(endMinutes: $0.endTotalMinutes, at: now) }
            .min { $0.startTotalMinutes < $1.startTotalMinutes }
    }

    /// 下一门课程的一句话摘要（传给 PersonaEngine）
    public var nextCourseSummary: String? {
        guard let next = nextUpcomingCourse else { return nil }
        let currentMinutes = CourseTimeRules.minutes(on: Date())
        let diff = next.startTotalMinutes - currentMinutes

        if diff > 0 {
            return EditorialCopy.text("course.next.soon", [
                "courseName": next.name, "classroom": next.classroom.isEmpty ? "教室" : next.classroom,
                "minutes": diff
            ])
        } else {
            return EditorialCopy.text("course.next.ongoing", [
                "courseName": next.name, "classroom": next.classroom.isEmpty ? "教室" : next.classroom
            ])
        }
    }

    public func addCourse(_ course: CourseItem) -> String? {
        guard let context = modelContext else {
            return EditorialCopy.text("course.databaseNotReady")
        }
        context.insert(course)
        do {
            try context.save()
        } catch {
            context.rollback()
            loadCourses()
            return EditorialCopy.text("course.addFailed", ["error": error.localizedDescription])
        }
        loadCourses()
        return nil
    }

    /// Save an editor draft into the existing record, preserving its identity.
    public func updateCourse(_ course: CourseItem, from draft: CourseItem) -> String? {
        guard let context = modelContext else {
            return EditorialCopy.text("course.databaseNotReady")
        }
        course.name = draft.name
        course.classroom = draft.classroom
        course.teacher = draft.teacher
        course.weekday = draft.weekday
        course.startHour = draft.startHour
        course.startMinute = draft.startMinute
        course.endHour = draft.endHour
        course.endMinute = draft.endMinute
        course.remindBeforeMinutes = draft.remindBeforeMinutes
        course.isEnabled = draft.isEnabled
        course.colorHex = draft.colorHex
        course.weekModeRaw = draft.weekModeRaw
        course.startWeek = draft.startWeek
        course.endWeek = draft.endWeek
        course.activeWeeksRaw = draft.activeWeeksRaw
        do {
            try context.save()
        } catch {
            context.rollback()
            loadCourses()
            return String(localized: "保存课程失败：\(error.localizedDescription)")
        }
        loadCourses()
        return nil
    }

    /// Delete every selected arrangement in one transaction, including all its weeks.
    public func deleteCourses(_ selected: [CourseItem]) -> String? {
        guard let context = modelContext else {
            return EditorialCopy.text("course.databaseNotReady")
        }
        for course in selected { context.delete(course) }
        do {
            try context.save()
        } catch {
            context.rollback()
            loadCourses()
            return EditorialCopy.text("course.deleteFailed", ["error": error.localizedDescription])
        }
        loadCourses()
        return nil
    }

    public func deleteCourse(_ course: CourseItem) {
        guard let context = modelContext else {
            showCourseOperationError(EditorialCopy.text("course.databaseNotReady"))
            return
        }
        context.delete(course)
        do {
            try context.save()
        } catch {
            context.rollback()
            showCourseOperationError(EditorialCopy.text("course.deleteFailed", ["error": error.localizedDescription]))
        }
        loadCourses()
    }

    public func toggleCourseEnabled(_ course: CourseItem) {
        guard let context = modelContext else {
            showCourseOperationError(EditorialCopy.text("course.databaseNotReady"))
            return
        }
        course.isEnabled.toggle()
        do {
            try context.save()
        } catch {
            context.rollback()
            loadCourses()
            showCourseOperationError(EditorialCopy.text("course.toggleFailed", ["error": error.localizedDescription]))
            return
        }
        CourseReminderService.shared.syncAllCourseReminders(courses: courses)
        updateWidgetSnapshot()
    }

    private func showCourseOperationError(_ message: String) {
        courseOperationErrorMessage = message
        isShowingCourseOperationError = true
    }

    // MARK: - .ics 课表导入支持

    public enum CourseImportMode: String, CaseIterable, Identifiable {
        case append = "追加到现有课表"
        case replace = "清空并覆盖现有课表"

        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .append: return String(localized: "追加到现有课表")
            case .replace: return String(localized: "清空并覆盖现有课表")
            }
        }
    }

    public struct CourseImportSummary {
        public let addedCount: Int
        public let mergedCount: Int
        public let unchangedCount: Int
        public let didSave: Bool

        public init(addedCount: Int = 0, mergedCount: Int = 0, unchangedCount: Int = 0, didSave: Bool = true) {
            self.addedCount = addedCount
            self.mergedCount = mergedCount
            self.unchangedCount = unchangedCount
            self.didSave = didSave
        }
    }

    /// 检查是否已有同名、同时间且地点/教师信息兼容的课程。
    public func isDuplicate(
        weekday: Int,
        startTotalMinutes: Int,
        endTotalMinutes: Int,
        name: String,
        classroom: String = "",
        teacher: String = ""
    ) -> Bool {
        courses.contains { course in
            course.weekday == weekday &&
            course.startTotalMinutes == startTotalMinutes &&
            course.endTotalMinutes == endTotalMinutes &&
            normalizedCourseText(course.name) == normalizedCourseText(name) &&
            compatibleMetadata(course.classroom, classroom) &&
            compatibleMetadata(course.teacher, teacher)
        }
    }

    private func normalizedCourseText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private func compatibleMetadata(_ existing: String, _ incoming: String) -> Bool {
        let lhs = normalizedCourseText(existing)
        let rhs = normalizedCourseText(incoming)
        return lhs.isEmpty || rhs.isEmpty || lhs == rhs
    }

    private func effectiveWeeks(for course: CourseItem) -> Set<Int> {
        course.effectiveWeeks
    }

    /// 检查某节课是否与已有课程存在时间段重叠冲突
    public func hasTimeConflict(weekday: Int, startTotalMinutes: Int, endTotalMinutes: Int, name: String, activeWeeks: Set<Int>) -> Bool {
        return courses.contains { course in
            guard course.weekday == weekday else { return false }
            guard !effectiveWeeks(for: course).isDisjoint(with: activeWeeks) else { return false }
            return CourseTimeRules.overlaps(start: course.startTotalMinutes, end: course.endTotalMinutes,
                                            otherStart: startTotalMinutes, otherEnd: endTotalMinutes)
        }
    }

    /// 批量导入课程
    @discardableResult
    public func importCourses(
        _ newCourses: [CourseItem],
        mode: CourseImportMode = .append
    ) -> CourseImportSummary {
        guard let context = modelContext else { return CourseImportSummary(didSave: false) }

        if mode == .replace {
            for course in courses {
                context.delete(course)
            }
            courses.removeAll()
        }

        var addedCount = 0
        var mergedCount = 0
        var unchangedCount = 0
        for course in newCourses {
            if let existing = courses.first(where: { existing in
                existing.weekday == course.weekday &&
                existing.startTotalMinutes == course.startTotalMinutes &&
                existing.endTotalMinutes == course.endTotalMinutes &&
                normalizedCourseText(existing.name) == normalizedCourseText(course.name) &&
                compatibleMetadata(existing.classroom, course.classroom) &&
                compatibleMetadata(existing.teacher, course.teacher)
            }) {
                let oldWeeks = effectiveWeeks(for: existing)
                let combinedWeeks = oldWeeks.union(effectiveWeeks(for: course))
                let metadataChanged = (existing.classroom.isEmpty && !course.classroom.isEmpty)
                    || (existing.teacher.isEmpty && !course.teacher.isEmpty)
                guard combinedWeeks != oldWeeks || metadataChanged else {
                    unchangedCount += 1
                    continue
                }

                existing.activeWeeks = combinedWeeks
                if let firstWeek = combinedWeeks.min() { existing.startWeek = firstWeek }
                if let lastWeek = combinedWeeks.max() { existing.endWeek = lastWeek }
                existing.weekModeRaw = CourseWeekMode.all.rawValue
                if existing.classroom.isEmpty { existing.classroom = course.classroom }
                if existing.teacher.isEmpty { existing.teacher = course.teacher }
                mergedCount += 1
                continue
            }
            context.insert(course)
            courses.append(course)
            addedCount += 1
        }

        do {
            try context.save()
        } catch {
            NSLog("导入课程保存失败：%@", error.localizedDescription)
            context.rollback()
            loadCourses()
            return CourseImportSummary(didSave: false)
        }
        loadCourses()
        return CourseImportSummary(
            addedCount: addedCount,
            mergedCount: mergedCount,
            unchangedCount: unchangedCount
        )
    }

    /// 接收系统“分享/用其他应用打开”传来的日历文件。
    @discardableResult
    public func handleExternalCalendarURL(_ url: URL) -> Bool {
        guard url.isFileURL, url.pathExtension.lowercased() == "ics" else { return false }
        isShowingAddSheet = false
        isShowingImportPicker = false
        externalImportRequestID = UUID()
        handleFileImportResult(.success(url))
        return true
    }

    /// 文档选择器与系统文件入口共用解析和权限释放流程。
    public func handleFileImportResult(_ result: Result<URL, Error>) {
        currentImportResult = nil
        isShowingImportPreview = false
        importErrorMessage = nil
        isShowingImportErrorAlert = false
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
                self.importErrorMessage = EditorialCopy.text("course.importEmpty")
                self.isShowingImportErrorAlert = true
            } else {
                self.importPresentationID = UUID()
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
        isSyncingCalendar = true
        Task {
            do {
                let count = try await CalendarSyncService.shared.syncCoursesToSystemCalendar(
                    courses: courses,
                    semesterStartDate: AppSettings.shared.semesterStartDate
                )
                self.isSyncingCalendar = false
                self.calendarSyncAlertMessage = EditorialCopy.text("course.calendarSyncSuccess", ["count": count])
                self.isShowingCalendarAlert = true
            } catch {
                self.isSyncingCalendar = false
                self.calendarSyncAlertMessage = EditorialCopy.text("course.calendarSyncFailed", ["error": error.localizedDescription])
                self.isShowingCalendarAlert = true
            }
        }
    }

    // MARK: - 小组件数据快照同步
    public func updateWidgetSnapshot() {
        let appGroupID = "group.com.qianyu.companion"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            NSLog("无法打开 App Group UserDefaults：%@", appGroupID)
            return
        }

        let snapshot = CourseWidgetScheduleSnapshot(
            semesterStartDate: AppSettings.shared.semesterStartDate,
            courses: courses.filter(\.isEnabled).map { course in
                CourseWidgetCourseSnapshot(
                    name: course.name,
                    classroom: course.classroom,
                    teacher: course.teacher,
                    weekday: course.weekday,
                    startMinutes: course.startTotalMinutes,
                    endMinutes: course.endTotalMinutes,
                    activeWeeks: effectiveWeeks(for: course).sorted()
                )
            }
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: "widget_schedule_v2")
        }

        if let course = self.nextUpcomingCourse {
            userDefaults.set(course.name, forKey: "widget_course_name")
            userDefaults.set(course.classroom.isEmpty ? EditorialCopy.text("course.widget.noClassroom") : course.classroom, forKey: "widget_classroom")
            userDefaults.set(course.formattedTime, forKey: "widget_time_string")
            userDefaults.set(course.teacher, forKey: "widget_teacher")
            userDefaults.set(AppSettings.shared.currentWeekDisplay, forKey: "widget_week_info")
            userDefaults.set(false, forKey: "widget_is_no_class")
        } else {
            userDefaults.set(EditorialCopy.text("course.widget.noClass"), forKey: "widget_course_name")
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
