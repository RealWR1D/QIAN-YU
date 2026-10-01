import Foundation
import CryptoKit

struct DailyPushMessage: Codable, Equatable {
    let title: String
    let body: String
}

struct DailyPushFacts {
    let courseCount: Int
    let totalMinutes: Int
    let remainingCount: Int
    let remainingMinutes: Int
    let lastEnd: Int?

    static func make(for date: Date, courses: [DailyPushPlanner.Course], semesterStart: Date,
                     calendar original: Calendar = .current) -> Self {
        var calendar = original
        calendar.firstWeekday = 2
        guard let semester = calendar.dateInterval(of: .weekOfYear, for: semesterStart)?.start,
              let monday = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
            return .init(courseCount: 0, totalMinutes: 0, remainingCount: 0, remainingMinutes: 0, lastEnd: nil)
        }
        let week = (calendar.dateComponents([.day], from: semester, to: monday).day ?? 0) / 7 + 1
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let active = courses.filter { $0.weekday == weekday && week > 0 && $0.weeks.contains(week)
            && $0.startMinutes >= 0 && $0.endMinutes <= 1440 && $0.endMinutes > $0.startMinutes }
        let remaining = active.filter { $0.endMinutes > minute }
        return .init(courseCount: active.count, totalMinutes: duration(active.map { ($0.startMinutes, $0.endMinutes) }),
            remainingCount: remaining.count, remainingMinutes: duration(remaining.map { (max(minute, $0.startMinutes), $0.endMinutes) }),
            lastEnd: active.map(\.endMinutes).max())
    }

    /// 重叠课程不重复累计占用时间，间隔也不计入课程时长。
    static func duration(_ intervals: [(Int, Int)]) -> Int {
        var total = 0
        var end = 0
        for (start, finish) in intervals.sorted(by: { $0.0 < $1.0 }) where finish > start {
            total += max(0, finish - max(start, end))
            end = max(end, finish)
        }
        return total
    }

    var summary: String {
        EditorialCopy.text("notification.context.course", ["courseCount": courseCount, "totalMinutes": totalMinutes,
            "remainingCount": remainingCount, "remainingMinutes": remainingMinutes])
    }
}

/// 缓存每条通知，并跨启动记住已经使用的正文；调整排程不会不断调用模型。
@MainActor final class DailyPushContentStore {
    struct Record: Codable {
        let fingerprint: String
        let message: DailyPushMessage
        let isAI: Bool
        let date: Date
    }
    private let defaults: UserDefaults
    private var records: [String: Record]
    private var used: Set<String>
    private let recordKey = "qianyu_push_content_v1"
    private let usedKey = "qianyu_push_used_bodies_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = (defaults.data(forKey: recordKey).flatMap { try? JSONDecoder().decode([String: Record].self, from: $0) }) ?? [:]
        used = Set(defaults.stringArray(forKey: usedKey) ?? [])
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func normalized(_ body: String) -> String {
        body.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0)
            && !CharacterSet.punctuationCharacters.contains($0) && !CharacterSet.symbols.contains($0) }.map(String.init).joined()
    }

    func record(id: String, fingerprint: String) -> Record? {
        guard let record = records[id], record.fingerprint == fingerprint else { return nil }
        return record
    }

    func accept(_ message: DailyPushMessage, id: String, fingerprint: String, date: Date, isAI: Bool) -> Bool {
        let clean = DailyPushMessage(title: message.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                    body: message.body.trimmingCharacters(in: .whitespacesAndNewlines))
        guard (2...28).contains(clean.title.count), (8...120).contains(clean.body.count),
              clean.body.rangeOfCharacter(from: .newlines) == nil, !used.contains(Self.digest(Self.normalized(clean.body))) else { return false }
        records[id] = .init(fingerprint: fingerprint, message: clean, isAI: isAI, date: date)
        used.insert(Self.digest(Self.normalized(clean.body)))
        records = records.filter { $0.value.date > Date().addingTimeInterval(-10 * 86400) }
        persist()
        return true
    }

    func fallback(entry: DailyPushPlanner.Entry, fingerprint: String, facts: DailyPushFacts, userName: String) -> DailyPushMessage {
        if let saved = record(id: entry.identifier, fingerprint: fingerprint) { return saved.message }
        let kind = entry.kind.rawValue
        let title = EditorialCopy.text("notification.\(kind).title", ["userName": userName])
        let key: String
        switch entry.kind {
        case .morning: key = "morning"
        case .lunch: key = facts.totalMinutes >= 240 || facts.courseCount >= 4 ? "lunch.busy" : "lunch.light"
        case .afternoon: key = "afternoon"
        case .dusk: key = facts.remainingCount > 0 ? "dusk.classes" : (facts.courseCount > 0 ? "dusk.done" : "dusk.free")
        case .evening: key = "evening"
        }
        let beginnings = EditorialCopy.list("notification.variation.opening").shuffled()
        let middles = EditorialCopy.list("notification.variation.\(key)").shuffled()
        let endings = EditorialCopy.list("notification.variation.ending").shuffled()
        for opening in beginnings {
            for middle in middles {
                for ending in endings {
                    let body = "\(opening)\(middle)\(ending)".replacingOccurrences(of: "{userName}", with: String(userName.prefix(12)))
                    let message = DailyPushMessage(title: String(title.prefix(28)), body: body)
                    if accept(message, id: entry.identifier, fingerprint: fingerprint, date: entry.date, isAI: false) { return message }
                }
            }
        }
        // 组合库耗尽时加入真实日期与时刻，仍是一句自然提醒，不伪造天气或课程。
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        for opening in beginnings {
            for middle in middles {
                for ending in endings {
                    let body = "给\(formatter.string(from: entry.date))的你：\(opening)\(middle)\(ending)"
                        .replacingOccurrences(of: "{userName}", with: String(userName.prefix(12)))
                    let message = DailyPushMessage(title: String(title.prefix(28)), body: body)
                    if accept(message, id: entry.identifier, fingerprint: fingerprint, date: entry.date, isAI: false) { return message }
                }
            }
        }
        // 同一时刻反复修改配置耗尽组合时，标注实际写信时刻，不编造未来事件。
        formatter.dateFormat = "M月d日 HH:mm:ss.SSS"
        while true {
            let body = "\(middles[0])\(endings[0])（\(formatter.string(from: Date()))写下的问候）"
            let message = DailyPushMessage(title: String(title.prefix(28)), body: body)
            if accept(message, id: entry.identifier, fingerprint: fingerprint, date: entry.date, isAI: false) { return message }
        }
    }

    var recentBodies: [String] { records.values.sorted { $0.date > $1.date }.prefix(12).map { $0.message.body } }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(records), forKey: recordKey)
        defaults.set(Array(used), forKey: usedKey)
    }
}
