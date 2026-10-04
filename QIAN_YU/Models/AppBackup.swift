import Foundation
import SwiftData

/// Versioned, explicit backup schema. Credentials and provider configuration are excluded.
struct AppBackup: Codable {
    let format: String
    let version: Int
    let userName: String
    let persona: String
    let semesterStart: Date
    let courses: [Course]
    let messages: [Message]
    struct Course: Codable {
        let id: UUID
        let name, classroom, teacher, colorHex, weekModeRaw, activeWeeksRaw: String
        let weekday, startHour, startMinute, endHour, endMinute, remindBeforeMinutes, startWeek, endWeek: Int
        let isEnabled: Bool
        init(_ c: CourseItem) {
            id=c.id; name=c.name; classroom=c.classroom; teacher=c.teacher; colorHex=c.colorHex; weekModeRaw=c.weekModeRaw; activeWeeksRaw=c.activeWeeksRaw
            weekday=c.weekday; startHour=c.startHour; startMinute=c.startMinute; endHour=c.endHour; endMinute=c.endMinute; remindBeforeMinutes=c.remindBeforeMinutes; startWeek=c.startWeek; endWeek=c.endWeek; isEnabled=c.isEnabled
        }
        func model() -> CourseItem {
            let c = CourseItem(id:id, name:name, classroom:classroom, teacher:teacher, weekday:weekday, startHour:startHour, startMinute:startMinute, endHour:endHour, endMinute:endMinute, remindBeforeMinutes:remindBeforeMinutes, isEnabled:isEnabled, colorHex:colorHex, weekModeRaw:weekModeRaw, startWeek:startWeek, endWeek:endWeek)
            c.activeWeeksRaw = activeWeeksRaw
            return c
        }
    }
    struct Message: Codable {
        let id: UUID
        let role, content: String
        let timestamp: Date
        let reasoning, error, tag: String?
        init(_ m: ChatMessage) { id=m.id; role=m.role; content=m.content; timestamp=m.timestamp; reasoning=m.reasoningContent; error=m.generationError; tag=m.tag }
        func model() -> ChatMessage {
            let m = ChatMessage(id:id, role:role, content:content, timestamp:timestamp, tag:tag, reasoningContent:reasoning)
            m.generationError = error
            return m
        }
    }
    @MainActor static func export(context: ModelContext, settings: AppSettings) throws -> Data {
        try context.save()
        let backup = AppBackup(format:"QIAN YU backup", version:1, userName:settings.userName, persona:settings.customPersonaPrompt, semesterStart:settings.semesterStartDate,
            courses:try context.fetch(FetchDescriptor<CourseItem>()).map(Course.init), messages:try context.fetch(FetchDescriptor<ChatMessage>()).map(Message.init))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
    @MainActor static func restore(_ data: Data, context: ModelContext, settings: AppSettings) throws {
        guard data.count <= 50_000_000 else { throw CocoaError(.fileReadTooLarge) }
        let backup = try JSONDecoder().decode(AppBackup.self, from:data)
        guard backup.format == "QIAN YU backup", backup.version == 1,
              backup.courses.count <= 10_000, backup.messages.count <= 100_000,
              backup.messages.allSatisfy({ ["user", "assistant", "system"].contains($0.role) }),
              backup.courses.allSatisfy({ (1...7).contains($0.weekday) && (0...23).contains($0.startHour) && (0...23).contains($0.endHour) && (0...59).contains($0.startMinute) && (0...59).contains($0.endMinute) && (1...520).contains($0.startWeek) && (1...520).contains($0.endWeek) && $0.endWeek >= $0.startWeek && $0.activeWeeksRaw.split(separator:",").count <= 520 && $0.activeWeeksRaw.split(separator:",").allSatisfy({ Int($0).map { (1...520).contains($0) } ?? false }) }) else { throw CocoaError(.fileReadCorruptFile) }
        // Merge by stable UUID. Never delete or overwrite existing records on restore.
        var courses = Set(try context.fetch(FetchDescriptor<CourseItem>()).map(\.id))
        var messages = Set(try context.fetch(FetchDescriptor<ChatMessage>()).map(\.id))
        try context.save()
        do {
            for c in backup.courses where courses.insert(c.id).inserted { context.insert(c.model()) }
            for m in backup.messages where messages.insert(m.id).inserted { context.insert(m.model()) }
            try context.save()
        } catch { context.rollback(); throw error }
        settings.userName = backup.userName; settings.customPersonaPrompt = backup.persona; settings.semesterStartDate = backup.semesterStart
    }
}
