import Foundation

@main enum CourseTimeChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func date(_ year: Int = 2026, _ month: Int = 10, _ day: Int = 5, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }
        let start = date()
        var checks = 0
        func check(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        check(CourseTimeRules.teachingWeek(on: date(2026, 10, 4), semesterStart: start, calendar: calendar) == 0, "pre-semester week")
        check(CourseTimeRules.displayWeek(on: date(2026, 10, 4), semesterStart: start, calendar: calendar) == 1, "display stays week 1")
        check(CourseTimeRules.teachingWeek(on: date(2026, 10, 11, 23, 59), semesterStart: start, calendar: calendar) == 1, "Sunday remains same week")
        check(CourseTimeRules.teachingWeek(on: date(2026, 10, 12), semesterStart: start, calendar: calendar) == 2, "Monday advances week")
        check(CourseTimeRules.teachingWeek(on: date(2027, 1, 4), semesterStart: date(2026, 12, 28), calendar: calendar) == 2, "year boundary")
        check(CourseTimeRules.monday(containing: date(2026, 10, 7), calendar: calendar) == start, "non-Monday semester date")
        check(CourseTimeRules.weekday(on: date(2026, 10, 11), calendar: calendar) == 7, "Sunday numbering")
        check(CourseTimeRules.weekday(on: start, calendar: calendar) == 1, "Monday numbering")
        check(CourseTimeRules.effectiveWeeks(explicit: [], start: 1, end: 6, mode: "oddOnly") == [1, 3, 5], "odd weeks")
        check(CourseTimeRules.effectiveWeeks(explicit: [], start: 1, end: 6, mode: "evenOnly") == [2, 4, 6], "even weeks")
        check(CourseTimeRules.effectiveWeeks(explicit: [2, 7], start: 1, end: 6, mode: "oddOnly") == [2, 7], "explicit overrides range")
        check(CourseTimeRules.effectiveWeeks(explicit: [-1, 0, 2], start: 1, end: 6, mode: "all") == [2], "invalid explicit weeks removed")
        check(CourseTimeRules.effectiveWeeks(explicit: [], start: 4, end: 2, mode: "all").isEmpty, "inverted range")
        check(CourseTimeRules.effectiveWeeks(explicit: [], start: 1, end: Int.max, mode: "all").isEmpty, "unbounded range")
        check(CourseTimeRules.classDay(week: 2, weekday: 7, semesterStart: start, calendar: calendar) == date(2026, 10, 18), "concrete week and day")
        check(CourseTimeRules.classDay(week: Int.max, weekday: 7, semesterStart: start, calendar: calendar) == nil, "date offset overflow")
        check(CourseTimeRules.classDay(week: 1, weekday: 0, semesterStart: start, calendar: calendar) == nil, "invalid weekday")
        check(CourseTimeRules.time(1485, on: start, calendar: calendar) == date(2026, 10, 6, 0, 45), "morning fallback crosses midnight")
        check(CourseTimeRules.time(-1, on: start, calendar: calendar) == nil, "invalid time")
        check(!CourseTimeRules.overlaps(start: 800, end: 840, otherStart: 840, otherEnd: 900), "adjacent classes do not overlap")
        check(CourseTimeRules.overlaps(start: 839, end: 841, otherStart: 840, otherEnd: 900), "one-minute overlap")
        let course = CourseScheduleRule(weekday: 1, startMinutes: 480, endMinutes: 580, weeks: [1, 3])
        check(CourseTimeRules.activeCourses(on: start, semesterStart: start, courses: [course], calendar: calendar) == [course], "active teaching day")
        check(CourseTimeRules.activeCourses(on: date(2026, 10, 12), semesterStart: start, courses: [course], calendar: calendar).isEmpty, "inactive teaching week")
        check(CourseTimeRules.activeCourses(on: date(2026, 9, 28), semesterStart: start, courses: [course], calendar: calendar).isEmpty, "no week-1 classes before semester")
        check(CourseTimeRules.hasNotEnded(endMinutes: 580, at: date(2026, 10, 5, 9, 40), calendar: calendar), "end minute retained")
        check(!CourseTimeRules.hasNotEnded(endMinutes: 580, at: date(2026, 10, 5, 9, 41), calendar: calendar), "next minute ended")
        var dst = Calendar(identifier: .gregorian)
        dst.timeZone = TimeZone(identifier: "America/New_York")!
        let springStart = dst.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let followingMonday = dst.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        check(CourseTimeRules.teachingWeek(on: followingMonday, semesterStart: springStart, calendar: dst) == 2, "DST uses calendar days")
        check(CourseTimeRules.classDay(week: 2, weekday: 1, semesterStart: springStart, calendar: dst) == followingMonday, "DST export matches teaching week")
        let springSunday = dst.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        let eightAM = CourseTimeRules.time(480, on: springSunday, calendar: dst)!
        check(dst.component(.hour, from: eightAM) == 8, "widget transition uses local clock time across DST")
        print("Course time checks passed: \(checks)")
    }
}
