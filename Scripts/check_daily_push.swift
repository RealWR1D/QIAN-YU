import Foundation

@main enum DailyPushChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        func date(_ day: Int = 5, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        func config(_ sleep: Bool = true) -> DailyPushPlanner.Configuration {
            .init(morning: 465, lunch: 720, afternoon: 840, evening: 1350,
                  followsSleep: sleep, semesterStart: date())
        }
        var count = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name); count += 1
        }
        func entries(_ courses: [DailyPushPlanner.Course], _ sleep: Bool = true,
                     now: Date? = nil, sent: Set<String> = []) -> [DailyPushPlanner.Entry] {
            DailyPushPlanner.entries(now: now ?? date(), configuration: config(sleep), courses: courses,
                                     sentIdentifiers: sent, calendar: calendar)
        }
        func first(_ kind: DailyPushPlanner.Kind, _ courses: [DailyPushPlanner.Course]) -> Date? {
            entries(courses).first { $0.kind == kind }?.date
        }
        func course(_ start: Int, _ end: Int, _ weeks: Set<Int> = [1]) -> DailyPushPlanner.Course {
            .init(weekday: 1, startMinutes: start, endMinutes: end, weeks: weeks)
        }
        check(first(.morning, []) == date(5, 8, 45), "morning fallback +1 hour")
        check(entries([], false).first { $0.kind == .morning }?.date == date(5, 7, 45), "fixed morning")
        check(first(.lunch, []) == date(5, 12), "no morning class fallback")
        check(first(.lunch, [course(480, 659)]) == date(5, 11, 30), "before 11")
        check(first(.lunch, [course(480, 660)]) == date(5, 11), "exactly 11")
        check(first(.lunch, [course(480, 610), course(640, 710)]) == date(5, 11, 50), "last morning class")
        check(first(.lunch, [course(480, 710, [2])]) == date(5, 12), "inactive week")
        check(first(.lunch, [course(720, 780)]) == date(5, 12), "afternoon class not lunch source")
        check(first(.afternoon, []) == nil, "no class skip")
        check(first(.afternoon, [course(800, 840)]) == nil, "ends at 14 skip")
        check(first(.afternoon, [course(900, 960)]) == nil, "starts at 15 skip")
        check(first(.afternoon, [course(839, 841)]) == date(5, 14), "overlap at 14")
        check(first(.afternoon, [course(870, 920)]) == date(5, 14), "overlap to 15")
        check(first(.afternoon, [course(840, 900, [2])]) == nil, "inactive afternoon")
        check(first(.evening, []) == date(5, 22, 30), "night fallback")
        let morning = DailyPushPlanner.sleepEntry(entering: false, now: date(5, 7), configuration: config(), calendar: calendar)
        check(morning?.date == date(5, 7), "early wake sends immediately")
        check(morning?.identifier == entries([]).first { $0.kind == .morning }?.identifier, "same ID replaces fallback")
        check(!entries([], sent: [morning!.identifier]).contains { $0.identifier == morning!.identifier }, "reschedule skips delivered")
        check(DailyPushPlanner.sleepEntry(entering: false, now: date(5, 8, 45), configuration: config(), calendar: calendar) == nil, "wake at deadline no duplicate")
        check(DailyPushPlanner.sleepEntry(entering: false, now: date(5, 9), configuration: config(), calendar: calendar) == nil, "late wake no duplicate")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(5, 21), configuration: config(), calendar: calendar)?.date == date(5, 21), "early sleep")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(5, 22, 30), configuration: config(), calendar: calendar) == nil, "night deadline")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(5, 23), configuration: config(), calendar: calendar) == nil, "late night")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(6, 1), configuration: config(), calendar: calendar) == nil, "after midnight no next-night message")
        check(DailyPushPlanner.sleepEntry(entering: false, now: date(5, 7), configuration: config(false), calendar: calendar) == nil, "disabled automation")
        let disabled = DailyPushPlanner.Configuration(morning: nil, lunch: nil, afternoon: nil, evening: nil, followsSleep: true, semesterStart: date())
        check(DailyPushPlanner.entries(now: date(), configuration: disabled, courses: [], calendar: calendar).isEmpty, "all disabled")
        check(entries([]).count == 21, "seven days reserve at most 28 slots")
        check(entries([], now: date(5, 13)).allSatisfy { $0.date > date(5, 13) }, "no past events")
        check(first(.lunch, [course(480, 710, [1, 3])]) == date(5, 11, 50), "explicit weeks")
        let lateMorning = DailyPushPlanner.Configuration(morning: 23 * 60 + 45, lunch: nil, afternoon: nil,
            evening: nil, followsSleep: true, semesterStart: date())
        check(DailyPushPlanner.entries(now: date(), configuration: lateMorning, courses: [], calendar: calendar).first?.date == date(6, 0, 45), "fallback hour crosses midnight")
        let beforeSemester = DailyPushPlanner.Configuration(morning: nil, lunch: 720, afternoon: 840,
            evening: nil, followsSleep: false, semesterStart: date(12))
        let before = DailyPushPlanner.entries(now: date(), configuration: beforeSemester,
            courses: [course(480, 710), course(840, 900)], calendar: calendar)
        check(before.first?.date == date(5, 12) && !before.contains { $0.kind == .afternoon }, "semester not started")
        let midnightBedtime = DailyPushPlanner.Configuration(morning: nil, lunch: nil, afternoon: nil,
            evening: 30, followsSleep: true, semesterStart: date())
        let beforeMidnight = DailyPushPlanner.sleepEntry(entering: true, now: date(5, 23), configuration: midnightBedtime, calendar: calendar)
        check(beforeMidnight?.identifier == DailyPushPlanner.identifier(.evening, day: date(6), calendar: calendar), "night before midnight uses next deadline")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(6, 0, 15), configuration: midnightBedtime, calendar: calendar)?.identifier == beforeMidnight?.identifier, "after midnight same bedtime ID")
        check(DailyPushPlanner.sleepEntry(entering: true, now: date(6, 0, 30), configuration: midnightBedtime, calendar: calendar) == nil, "midnight deadline")
        let five = DailyPushPlanner.Configuration(morning: 465, lunch: 720, afternoon: 825, dusk: 1080,
            evening: 1350, followsSleep: true, semesterStart: date())
        let fiveEntries = DailyPushPlanner.entries(now: date(), configuration: five,
            courses: [course(840, 900)], calendar: calendar)
        check(fiveEntries.first { $0.kind == .afternoon }?.date == date(5, 13, 45), "afternoon now defaults to 13:45")
        check(fiveEntries.first { $0.kind == .dusk }?.date == date(5, 18), "independent dusk at 18")
        check(fiveEntries.count <= 35, "five periods fit seven day budget")
        check(DailyPushPlanner.entries(now: date(5, 19), configuration: five, courses: [], calendar: calendar)
            .first { $0.kind == .dusk }?.date == date(6, 18), "past dusk not retroactive")
        print("Daily push checks passed: \(count)")
    }
}
