//
//  QianYuCourseWidget.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
#if canImport(WidgetKit)
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
        courseName: String = "高等数学 (上)",
        classroom: String = "正心楼 312",
        timeString: String = "08:30 - 10:05",
        teacher: String = "张教授",
        weekInfo: String = "第 4 周 · 双周",
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
        completion(fetchCurrentEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CourseWidgetEntry>) -> Void) {
        let currentEntry = fetchCurrentEntry()
        // 每 15 分钟刷新一次小组件
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> CourseWidgetEntry {
        let appGroupID = "group.com.qianyu.companion"
        let userDefaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard

        let isNoClass = userDefaults.object(forKey: "widget_is_no_class") as? Bool ?? false
        let name = userDefaults.string(forKey: "widget_course_name") ?? "高等数学 (上)"
        let classroom = userDefaults.string(forKey: "widget_classroom") ?? "正心楼 312"
        let timeString = userDefaults.string(forKey: "widget_time_string") ?? "08:30 - 10:05"
        let teacher = userDefaults.string(forKey: "widget_teacher") ?? "张教授"
        let weekInfo = userDefaults.string(forKey: "widget_week_info") ?? AppSettings.shared.currentWeekDisplay

        return CourseWidgetEntry(
            date: Date(),
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
        .configurationDisplayName("千语课程表")
        .description("一眼掌握下节上课教室与时间，陈千语全程陪伴。")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
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
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        #if os(iOS)
        case .accessoryCircular:
            circularLockScreenView
        case .accessoryRectangular:
            rectangularLockScreenView
        #endif
        default:
            smallView
        }
    }

    // MARK: - 桌面小号小组件 (Small)
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 小陈微缩插槽 (无剑标)
                chibiMiniAvatar(size: 24)

                Text("下节课")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)

                Spacer()

                Text(entry.weekInfo.components(separatedBy: " · ").first ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if entry.isNoClass {
                Text("今日已无课")
                    .font(.system(size: 15, weight: .bold))
                Text("「下课啦！带我去后山转转！」")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text(entry.courseName)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(entry.timeString)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)

                if !entry.classroom.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(entry.classroom)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
    }

    // MARK: - 桌面中号小组件 (Medium)
    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧小陈陪伴立像区
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    chibiMiniAvatar(size: 32)
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
                    Text("即将到来的课程")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text(entry.courseName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label(entry.timeString, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if !entry.classroom.isEmpty {
                        Label(entry.classroom, systemImage: "location.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                if !entry.teacher.isEmpty {
                    Label("授课：\(entry.teacher)", systemImage: "person")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
    }

    #if os(iOS)
    // MARK: - 锁屏圆形小组件 (Accessory Circular)
    private var circularLockScreenView: some View {
        VStack(spacing: 2) {
            Image(systemName: "calendar")
                .font(.system(size: 14))
            Text(entry.courseName.prefix(2))
                .font(.system(size: 12, weight: .bold))
            Text(entry.timeString.prefix(5))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 锁屏矩形小组件 (Accessory Rectangular)
    private var rectangularLockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("下节: \(entry.courseName)")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            Text("\(entry.timeString) · \(entry.classroom)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(entry.weekInfo)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    #endif

    // MARK: - 辅助微缩头像 (无剑标)
    private func chibiMiniAvatar(size: CGFloat) -> some View {
        ZStack {
            #if os(macOS)
            if let nsImg = NSImage(named: "qianyu_chibi_avatar") ?? NSImage(named: "chen_qianyu_avatar") {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackCircle(size: size)
            }
            #else
            if let uiImg = UIImage(named: "qianyu_chibi_avatar") ?? UIImage(named: "chen_qianyu_avatar") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackCircle(size: size)
            }
            #endif
        }
    }

    private func fallbackCircle(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text("千")
                .font(.system(size: max(8, size * 0.55), weight: .bold))
                .foregroundColor(.white)
        }
    }
}
#endif
