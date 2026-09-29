import Foundation

/// 固定台词、通知和人设的唯一内容来源。修改文字只需编辑 EditorialContent.json。
public enum EditorialCopy {
    public struct QuickAction: Decodable {
        public let title: String
        public let prompt: String
    }

    private struct Content: Decodable {
        let strings: [String: String]
        let lists: [String: [String]]
        let quickActions: [QuickAction]
    }

    private static let content: Content = {
        guard let url = Bundle.main.url(forResource: "EditorialContent", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(Content.self, from: data) else {
            preconditionFailure("EditorialContent.json 未能从 App 资源中读取")
        }
        return content
    }()

    public static func text(_ key: String, _ values: [String: CustomStringConvertible] = [:]) -> String {
        guard let template = content.strings[key] else {
            preconditionFailure("EditorialContent.json 缺少文案：\(key)")
        }
        var result = template
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{\(name)}", with: value.description)
        }
        return result
    }

    public static func list(_ key: String) -> [String] {
        guard let values = content.lists[key], !values.isEmpty else {
            preconditionFailure("EditorialContent.json 缺少文案列表：\(key)")
        }
        return values
    }

    public static var quickActions: [QuickAction] { content.quickActions }
}
