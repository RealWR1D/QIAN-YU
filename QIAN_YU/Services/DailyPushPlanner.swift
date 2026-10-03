import Foundation

/// 纯排程规则，独立于通知权限、SwiftData 和快捷指令。
enum DailyPushPlanner {
    typealias Course = CourseScheduleRule

    struct Configuration {
        let morning: Int?
        let lunch: Int?
        let afternoon: Int?
        var dusk: Int? = nil
        let evening: Int?
        let followsSleep: Bool
        let semesterStart: Date
    }

    enum Kind: String { case morning, lunch, afternoon, dusk, evening }
    struct Entry {
        let kind: Kind
        let date: Date
        let identifier: String
    }

    static let horizonDays = 7

    static func identifier(_ kind: Kind, day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return "qianyu_daily_\(kind.rawValue)_\(parts.year!)-\(parts.month!)-\(parts.day!)"
    }

    static func time(_ minutes: Int, on day: Date, calendar: Calendar) -> Date? {
        CourseTimeRules.time(minutes, on: day, calendar: calendar)
    }

    static func entries(now: Date, configuration: Configuration, courses: [Course],
                        sentIdentifiers: Set<String> = [], calendar original: Calendar = .current) -> [Entry] {
        let calendar = CourseTimeRules.teachingCalendar(original)
        var result: [Entry] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            let active = CourseTimeRules.activeCourses(on: day, semesterStart: configuration.semesterStart,
                                                       courses: courses, calendar: calendar)

            func append(_ kind: Kind, minutes: Int?) {
                guard let minutes, let date = time(minutes, on: day, calendar: calendar), date > now else { return }
                let id = identifier(kind, day: day, calendar: calendar)
                if !sentIdentifiers.contains(id) { result.append(Entry(kind: kind, date: date, identifier: id)) }
            }

            // 开启睡眠联动后，将晨间设定时间延后一小时作为兜底。
            if let morning = configuration.morning {
                append(.morning, minutes: configuration.followsSleep ? morning + 60 : morning)
            }
            if let lunch = configuration.lunch {
                // 上午开始的最后一堂课结束后用餐；当天无上午课时保留用户设定。
                let end = active.filter { $0.startMinutes < 12 * 60 }.map(\.endMinutes).max()
                append(.lunch, minutes: end.map { $0 < 11 * 60 ? 11 * 60 + 30 : $0 } ?? lunch)
            }
            if let afternoon = configuration.afternoon,
               active.contains(where: { CourseTimeRules.overlaps(start: $0.startMinutes, end: $0.endMinutes, otherStart: 14 * 60, otherEnd: 15 * 60) }) {
                append(.afternoon, minutes: afternoon)
            }
            append(.dusk, minutes: configuration.dusk)
            append(.evening, minutes: configuration.evening)
        }
        return result.sorted { $0.date < $1.date }
    }

    /// 同一天提前触发后，使用与兜底通知相同的标识，替换而非追加。
    static func sleepEntry(entering: Bool, now: Date, configuration: Configuration,
                           calendar: Calendar = .current) -> Entry? {
        guard configuration.followsSleep else { return nil }
        let hour = calendar.component(.hour, from: now)
        let kind: Kind = entering ? .evening : .morning
        let day: Date
        let deadlineMinutes: Int
        if entering {
            guard let evening = configuration.evening else { return nil }
            // 凌晨的就寝时间属于前一晚；普通晚间时间在凌晨已过截止时间。
            let offset = evening < 12 * 60 && hour >= 12 ? 1 : (evening >= 12 * 60 && hour < 12 ? -1 : 0)
            guard let anchor = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            day = anchor
            deadlineMinutes = evening
        } else {
            guard hour < 12, let morning = configuration.morning else { return nil }
            day = now
            deadlineMinutes = morning + 60
        }
        guard let deadline = time(deadlineMinutes, on: day, calendar: calendar), now < deadline else { return nil }
        return Entry(kind: kind, date: now, identifier: identifier(kind, day: day, calendar: calendar))
    }
}
