import Foundation
import SwiftData

@main
struct DistributionStorageCheck {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let schema = Schema([ChatMessage.self, CourseItem.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        precondition(configuration.url == url)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if CommandLine.arguments[1] == "write" {
            container.mainContext.insert(ChatMessage(role: "user", content: "distribution persistence check"))
            container.mainContext.insert(CourseItem(name: "distribution course check"))
            try container.mainContext.save()
        } else {
            let messages = try container.mainContext.fetch(FetchDescriptor<ChatMessage>())
            let courses = try container.mainContext.fetch(FetchDescriptor<CourseItem>())
            precondition(messages.count == 1 && messages[0].content == "distribution persistence check")
            precondition(courses.count == 1 && courses[0].name == "distribution course check")
            print("Ad hoc distribution database write and fresh-process read passed")
        }
    }
}
