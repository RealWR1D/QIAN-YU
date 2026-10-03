//
//  QianYuCourseWidget.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
#if canImport(WidgetKit)

public struct CourseWidgetCourseSnapshot: Codable {
    public let name: String
    public let classroom: String
    public let teacher: String
    public let weekday: Int
    public let startMinutes: Int
    public let endMinutes: Int
    public let activeWeeks: [Int]

    public init(name: String, classroom: String, teacher: String, weekday: Int, startMinutes: Int, endMinutes: Int, activeWeeks: [Int]) {
        self.name = name
        self.classroom = classroom
        self.teacher = teacher
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.activeWeeks = activeWeeks
    }
}

public struct CourseWidgetScheduleSnapshot: Codable {
    public let semesterStartDate: Date
    public let courses: [CourseWidgetCourseSnapshot]
}
import WidgetKit
#endif

#if canImport(WidgetKit)

public struct CourseWidgetEntry: TimelineEntry {
    public let date: Date
    public let courseName: String
    public let classroom: String
    public let timeString: String
    public let teacher: String
    public let weekInfo: String
    public let isNoClass: Bool

    public init(
        date: Date = Date(),
        courseName: String = String(localized: "高等数学 (上)"),
        classroom: String = String(localized: "正心楼 312"),
        timeString: String = "08:30 - 10:05",
        teacher: String = String(localized: "张教授"),
        weekInfo: String = String(localized: "第 4 周 · 双周"),
        isNoClass: Bool = false
    ) {
        self.date = date
        self.courseName = courseName
        self.classroom = classroom
        self.timeString = timeString
        self.teacher = teacher
        self.weekInfo = weekInfo
        self.isNoClass = isNoClass
    }
}

public struct CourseWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> CourseWidgetEntry {
        CourseWidgetEntry()
    }

    public func getSnapshot(in context: Context, completion: @escaping (CourseWidgetEntry) -> Void) {
        completion(fetchCurrentEntry(at: Date()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CourseWidgetEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        var transitionDates = [now]
        if let schedule = readSchedule() {
            for dayOffset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
                if day > now { transitionDates.append(day) }
                for course in schedule.courses {
                    for minute in [course.startMinutes, course.endMinutes + 1] {
                        if let transition = CourseTimeRules.time(minute, on: day, calendar: calendar), transition > now {
                            transitionDates.append(transition)
                        }
                    }
                }
            }
        }
        let entries = Set(transitionDates).sorted().map { fetchCurrentEntry(at: $0) }
        let nextUpdate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readSchedule() -> CourseWidgetScheduleSnapshot? {
        guard let defaults = UserDefaults(suiteName: "group.com.qianyu.companion"),
              let data = defaults.data(forKey: "widget_schedule_v2") else { return nil }
        return try? JSONDecoder().decode(CourseWidgetScheduleSnapshot.self, from: data)
    }

    private func fetchCurrentEntry(at date: Date) -> CourseWidgetEntry {
        if let schedule = readSchedule() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let week = CourseTimeRules.displayWeek(on: date, semesterStart: schedule.semesterStartDate, calendar: calendar)
            let teachingWeek = CourseTimeRules.teachingWeek(on: date, semesterStart: schedule.semesterStartDate, calendar: calendar)
            let weekday = CourseTimeRules.weekday(on: date, calendar: calendar)
            let next = schedule.courses
                .filter { teachingWeek > 0 && $0.weekday == weekday && $0.activeWeeks.contains(teachingWeek)
                    && CourseTimeRules.hasNotEnded(endMinutes: $0.endMinutes, at: date, calendar: calendar) }
                .min { $0.startMinutes < $1.startMinutes }
            let weekType = week % 2 == 0 ? String(localized: "双周") : String(localized: "单周")
            let weekInfo = String(localized: "第 \(week) 周 · \(weekType)")
            guard let next else {
                return CourseWidgetEntry(date: date, courseName: "今日已无课", classroom: "", timeString: "", teacher: "", weekInfo: weekInfo, isNoClass: true)
            }
            let timeString = String(format: "%02d:%02d - %02d:%02d", next.startMinutes / 60, next.startMinutes % 60, next.endMinutes / 60, next.endMinutes % 60)
            return CourseWidgetEntry(date: date, courseName: next.name, classroom: next.classroom.isEmpty ? String(localized: "教室未指定") : next.classroom, timeString: timeString, teacher: next.teacher, weekInfo: weekInfo)
        }

        let appGroupID = "group.com.qianyu.companion"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            NSLog("无法打开 App Group UserDefaults：%@", appGroupID)
            return CourseWidgetEntry(
                date: date,
                courseName: String(localized: "无法读取共享课表"),
                classroom: String(localized: "请检查 App Group 配置"),
                timeString: "",
                teacher: "",
                weekInfo: "",
                isNoClass: false
            )
        }

        let isNoClass = userDefaults.object(forKey: "widget_is_no_class") as? Bool ?? false
        let name = userDefaults.string(forKey: "widget_course_name") ?? String(localized: "高等数学 (上)")
        let classroom = userDefaults.string(forKey: "widget_classroom") ?? String(localized: "正心楼 312")
        let timeString = userDefaults.string(forKey: "widget_time_string") ?? "08:30 - 10:05"
        let teacher = userDefaults.string(forKey: "widget_teacher") ?? String(localized: "张教授")
        let weekInfo = userDefaults.string(forKey: "widget_week_info") ?? String(localized: "第 1 周")

        return CourseWidgetEntry(
            date: date,
            courseName: name,
            classroom: classroom,
            timeString: timeString,
            teacher: teacher,
            weekInfo: weekInfo,
            isNoClass: isNoClass
        )
    }
}

public struct QianYuCourseWidget: Widget {
    public let kind: String = "QianYuCourseWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseWidgetProvider()) { entry in
            CourseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("QIAN YU 课表")
        .description("一眼掌握下节上课教室与时间，陈千语全程随行陪伴。")
        #if os(iOS)
        .supportedFamilies([
            .systemSmall,              // 桌面 2x2
            .systemMedium,             // 桌面 2x4
            .accessoryCircular,        // 锁屏圆形
            .accessoryRectangular,     // 锁屏长矩形
            .accessoryInline           // 锁屏时间上方单行
        ])
        .contentMarginsDisabled()
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        #endif
    }
}

public struct CourseWidgetEntryView: View {
    public let entry: CourseWidgetEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: CourseWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
                    .qianYuWidgetContainerBackground()
            case .systemMedium:
                mediumView
                    .qianYuWidgetContainerBackground()
            #if os(iOS)
            case .accessoryCircular:
                circularLockScreenView
                    .qianYuLockScreenContainerBackground()
            case .accessoryRectangular:
                rectangularLockScreenView
                    .qianYuLockScreenContainerBackground()
            case .accessoryInline:
                inlineLockScreenView
                    .qianYuLockScreenContainerBackground()
            #endif
            default:
                smallView
                    .qianYuWidgetContainerBackground()
            }
        }
    }

    // MARK: - 桌面 2x2 小号小组件 (SystemSmall - 黄金比例与饱满视觉布局)
    public var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 顶部栏：小陈头像 + 标题 + 周次胶囊
            HStack(alignment: .center, spacing: 6) {
                chibiMiniAvatar(size: 26)

                Text("QIAN YU")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)

                Spacer(minLength: 4)

                let weekTag = entry.weekInfo.components(separatedBy: " · ").first ?? String(localized: "本周")
                Text(weekTag)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 6)

            // 2. 中部核心内容：日程卡片
            if entry.isNoClass {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        Text("今日已无课")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }

                    Text("「下课啦！带我去后山转转，或者喝杯奶茶？」")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text("下节日程")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Spacer()
                        if !entry.teacher.isEmpty {
                            Text(entry.teacher)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(entry.courseName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text(entry.timeString)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)

                    if !entry.classroom.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(entry.classroom)
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 6)

            // 3. 底部语音气泡卡片：消除尴尬空白，横向撑满
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange.opacity(0.85))
                Text(entry.isNoClass ? "「随时喊我，我都在呢！」" : "「当破即破，冲冲冲！」")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 桌面 2x4 中号小组件 (SystemMedium)
    public var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧小陈陪伴立像区
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    chibiMiniAvatar(size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("陈千语")
                            .font(.system(size: 13, weight: .bold))
                        Text("特勤干员 · 随行")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(entry.weekInfo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())

                Text("「当破即破，冲冲冲！」")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 130)

            Divider()

            // 右侧课程日程详情
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.isNoClass ? "今日课表" : "即将到来的课程")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if entry.isNoClass {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日已无任何课程")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        Text("「终于可以歇一歇啦！走，管理员，去菈梵朵玛碰碰杯杯喝奶茶！」")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    Text(entry.courseName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(entry.timeString, systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if !entry.classroom.isEmpty {
                            Label(entry.classroom, systemImage: "location.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }

                    if !entry.teacher.isEmpty {
                        Label("授课教师：\(entry.teacher)", systemImage: "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if os(iOS)
    // MARK: - 锁屏单行小组件 (Accessory Inline)
    @ViewBuilder
    public var inlineLockScreenView: some View {
        if entry.isNoClass {
            Label("今日已无课 · 享受闲暇", systemImage: "sparkles")
        } else {
            let start = entry.timeString.components(separatedBy: " - ").first ?? entry.timeString
            Label("下节: \(entry.courseName) \(start)", systemImage: "graduationcap.fill")
        }
    }

    // MARK: - 锁屏圆形小组件 (Accessory Circular)
    @ViewBuilder
    public var circularLockScreenView: some View {
        ZStack {
            #if canImport(WidgetKit)
            if #available(iOS 16.0, *) {
                AccessoryWidgetBackground()
            }
            #endif

            VStack(spacing: 1) {
                if entry.isNoClass {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("无课")
                        .font(.system(size: 11, weight: .bold))
                } else {
                    Text(String(entry.courseName.prefix(2)))
                        .font(.system(size: 12, weight: .bold))
                    let start = entry.timeString.components(separatedBy: " - ").first ?? entry.timeString
                    Text(start)
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                    if !entry.classroom.isEmpty {
                        Text(String(entry.classroom.prefix(3)))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 锁屏长矩形小组件 (Accessory Rectangular)
    @ViewBuilder
    public var rectangularLockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isNoClass {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("QIAN YU · 今日无课")
                        .font(.system(size: 12, weight: .bold))
                }
                Text("「下课啦！带我去后山转转！」")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(entry.weekInfo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 11))
                    Text("下节: \(entry.courseName)")
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Label(entry.timeString, systemImage: "clock")
                        .font(.system(size: 10, weight: .medium))
                    if !entry.classroom.isEmpty {
                        Text("· \(entry.classroom)")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)

                Text("\(entry.weekInfo) · \(entry.teacher.isEmpty ? "陈千语随行" : entry.teacher)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
    #endif

    // MARK: - 辅助微缩头像
    public func chibiMiniAvatar(size: CGFloat) -> some View {
        QianYuChibiMiniAvatarView(size: size, assetName: "QianyuAvatar")
    }

}

// MARK: - 跨平台 Widget 容器背景修饰符
public extension View {
    @ViewBuilder
    func qianYuWidgetContainerBackground() -> some View {
        #if os(iOS)
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.12),
                        Color.pink.opacity(0.04),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            self.background(
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.12),
                        Color.pink.opacity(0.04),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        #else
        if #available(macOSApplicationExtension 14.0, macOS 14.0, *) {
            self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.12),
                        Color.pink.opacity(0.04),
                        Color(nsColor: .windowBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            self.background(
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.12),
                        Color.pink.opacity(0.04),
                        Color(nsColor: .windowBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        #endif
    }

    @ViewBuilder
    func qianYuLockScreenContainerBackground() -> some View {
        #if os(iOS)
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            self.containerBackground(.clear, for: .widget)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
#endif
