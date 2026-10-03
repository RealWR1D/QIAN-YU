import Foundation

/// Immutable input shared by notifications, daily messages and widget queries.
/// Only enabled courses should be converted to this type.
public struct CourseScheduleRule: Equatable {
    public let weekday: Int
    public let startMinutes: Int
    public let endMinutes: Int
    public let weeks: Set<Int>

    public init(weekday: Int, startMinutes: Int, endMinutes: Int, weeks: Set<Int>) {
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.weeks = weeks
    }
}

/// Pure calendar rules. All callers can supply a fixed date and time zone.
/// Displaying week 1 before semester starts must not activate week-1 courses.
public enum CourseTimeRules {
    public static func teachingCalendar(_ original: Calendar = .current) -> Calendar {
        var calendar = original
        calendar.firstWeekday = 2
        return calendar
    }

    public static func monday(containing date: Date, calendar: Calendar = .current) -> Date {
        let calendar = teachingCalendar(calendar)
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    public static func teachingWeek(on date: Date, semesterStart: Date, calendar: Calendar = .current) -> Int {
        let calendar = teachingCalendar(calendar)
        let days = calendar.dateComponents([.day], from: monday(containing: semesterStart, calendar: calendar),
                                           to: monday(containing: date, calendar: calendar)).day ?? 0
        return days / 7 + 1
    }

    public static func displayWeek(on date: Date, semesterStart: Date, calendar: Calendar = .current) -> Int {
        max(1, teachingWeek(on: date, semesterStart: semesterStart, calendar: calendar))
    }

    public static func weekday(on date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    public static func minutes(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    public static func effectiveWeeks(explicit: Set<Int>, start: Int, end: Int, mode: String) -> Set<Int> {
        if !explicit.isEmpty { return Set(explicit.filter { $0 > 0 }) }
        guard start > 0, end >= start, end - start <= 100 else { return [] }
        return Set((start...end).filter {
            switch mode {
            case "oddOnly": return $0 % 2 != 0
            case "evenOnly": return $0 % 2 == 0
            default: return true
            }
        })
    }

    public static func activeCourses(on date: Date, semesterStart: Date, courses: [CourseScheduleRule],
                                     calendar: Calendar = .current) -> [CourseScheduleRule] {
        let week = teachingWeek(on: date, semesterStart: semesterStart, calendar: calendar)
        let day = weekday(on: date, calendar: calendar)
        return courses.filter { week > 0 && $0.weekday == day && $0.weeks.contains(week)
            && $0.startMinutes >= 0 && $0.endMinutes <= 1440 && $0.endMinutes > $0.startMinutes }
    }

    public static func overlaps(start: Int, end: Int, otherStart: Int, otherEnd: Int) -> Bool {
        max(start, otherStart) < min(end, otherEnd)
    }

    /// Existing course UI treats the end minute as part of the current class.
    public static func hasNotEnded(endMinutes: Int, at date: Date, calendar: Calendar = .current) -> Bool {
        endMinutes >= minutes(on: date, calendar: calendar)
    }

    public static func classDay(week: Int, weekday: Int, semesterStart: Date,
                                calendar: Calendar = .current) -> Date? {
        guard week > 0, (1...7).contains(weekday) else { return nil }
        let (offset, overflow) = (week - 1).multipliedReportingOverflow(by: 7)
        let (days, additionOverflow) = offset.addingReportingOverflow(weekday - 1)
        guard !overflow, !additionOverflow else { return nil }
        return calendar.date(byAdding: .day, value: days, to: monday(containing: semesterStart, calendar: calendar))
    }

    /// Allows the extra hour used by morning notification fallback after midnight.
    public static func time(_ minutes: Int, on day: Date, calendar: Calendar = .current) -> Date? {
        guard (0..<1500).contains(minutes),
              let target = calendar.date(byAdding: .day, value: minutes / 1440, to: day) else { return nil }
        return calendar.date(bySettingHour: (minutes % 1440) / 60, minute: minutes % 60, second: 0, of: target)
    }
}
