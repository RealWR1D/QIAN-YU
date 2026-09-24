//
//  AICourseParserService.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI

public struct ParsedCourseDTO: Codable, Identifiable {
    public var id = UUID()
    public var name: String
    public var classroom: String
    public var teacher: String
    public var weekday: Int // 1=周一 ... 7=周日
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var weekModeRaw: String // "all", "oddOnly", "evenOnly"
    public var startWeek: Int
    public var endWeek: Int

    public func toCourseItem() -> CourseItem {
        CourseItem(
            name: name,
            classroom: classroom,
            teacher: teacher,
            weekday: weekday,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            remindBeforeMinutes: 15,
            isEnabled: true,
            colorHex: randomColorHex(),
            weekModeRaw: weekModeRaw,
            startWeek: startWeek,
            endWeek: endWeek
        )
    }

    private func randomColorHex() -> String {
        let colors = ["#FF9500", "#FF2D55", "#5856D6", "#007AFF", "#34C759", "#AF52DE", "#FF3B30", "#30B0C7"]
        return colors[abs(name.hashValue) % colors.count]
    }
}

public final class AICourseParserService {
    public static let shared = AICourseParserService()

    private init() {}

    /// 使用配置的大模型解析课表文本或截图信息
    public func parseWithAI(
        text: String,
        imageBase64: String? = nil,
        baseURL: String = AppSettings.shared.apiBaseURL,
        apiKey: String = AppSettings.shared.apiKey,
        model: String = AppSettings.shared.modelName
    ) async throws -> [ParsedCourseDTO] {
        // 如果未填 API Key，退回到离线智能正则解析
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return parseOfflineText(text)
        }

        let systemPrompt = """
        你是一个专业的学生课表信息提取引擎。你的任务是将用户提供的课表文本或描述解析为结构化的 JSON 数组。
        返回必须且只能是一个纯 JSON 数组，严禁包含任何 Markdown 格式声明、代码块标记（如 ```json）或解释文字。

        JSON 数组中每个对象必须严格包含以下字段：
        - "name": string 课程名称（如 "高等数学"）
        - "classroom": string 教室或上课地点，未知填空字符串
        - "teacher": string 教师姓名，未知填空字符串
        - "weekday": int 星期几 (1=周一, 2=周二, 3=周三, 4=周四, 5=周五, 6=周六, 7=周日)
        - "startHour": int 开始小时 (0-23)
        - "startMinute": int 开始分钟 (0-59)
        - "endHour": int 结束小时 (0-23)
        - "endMinute": int 结束分钟 (0-59)
        - "weekModeRaw": string 周数规则 ("all"=单双周都上, "oddOnly"=仅单周, "evenOnly"=仅双周)
        - "startWeek": int 起始周数 (默认 1)
        - "endWeek": int 结束周数 (默认 16)

        示例输出格式：
        [{"name":"线性代数","classroom":"正心楼312","teacher":"王教授","weekday":1,"startHour":8,"startMinute":30,"endHour":10,"endMinute":5,"weekModeRaw":"all","startWeek":1,"endWeek":16}]
        """

        var urlString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasSuffix("/chat/completions") && !urlString.hasSuffix("/") {
            urlString += "/chat/completions"
        }
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")

        let messagesPayload: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请解析以下课表内容：\n\(text)"]
        ]

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messagesPayload,
            "temperature": 0.1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // 云端请求失败，退回到离线规则解析
            return parseOfflineText(text)
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return parseOfflineText(text)
        }

        // 清洗内容中的 markdown 代码块标记与前后闲聊废话
        var cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除 <think>...</think> 思考内容，避免其内部的括号干扰 JSON 数组提取
        if let thinkRegex = try? NSRegularExpression(pattern: #"<think>[\s\S]*?</think>"#, options: []) {
            cleanContent = thinkRegex.stringByReplacingMatches(in: cleanContent, options: [], range: NSRange(cleanContent.startIndex..., in: cleanContent), withTemplate: "")
        }

        if cleanContent.hasPrefix("```json") {
            cleanContent = String(cleanContent.dropFirst(7))
        } else if cleanContent.hasPrefix("```") {
            cleanContent = String(cleanContent.dropFirst(3))
        }
        if cleanContent.hasSuffix("```") {
            cleanContent = String(cleanContent.dropLast(3))
        }
        cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // 提取首个 [ 与末尾 ] 之间的有效 JSON 数组核心内容
        if let firstBracket = cleanContent.firstIndex(of: "["),
           let lastBracket = cleanContent.lastIndex(of: "]"),
           firstBracket <= lastBracket {
            cleanContent = String(cleanContent[firstBracket...lastBracket])
        }

        guard let jsonData = cleanContent.data(using: .utf8),
              let parsedList = try? JSONDecoder().decode([ParsedCourseDTO].self, from: jsonData) else {
            return parseOfflineText(text)
        }

        return parsedList
    }

    /// 离线规则快速解析（无需 API Key）
    public func parseOfflineText(_ text: String) -> [ParsedCourseDTO] {
        var results: [ParsedCourseDTO] = []
        let lines = text.components(separatedBy: .newlines)

        let weekdayMap: [String: Int] = [
            "周一": 1, "星期一": 1, "礼拜一": 1, "周1": 1, "mon": 1,
            "周二": 2, "星期二": 2, "礼拜二": 2, "周2": 2, "tue": 2,
            "周三": 3, "星期三": 3, "礼拜三": 3, "周3": 3, "wed": 3,
            "周四": 4, "星期四": 4, "礼拜四": 4, "周4": 4, "thu": 4,
            "周五": 5, "星期五": 5, "礼拜五": 5, "周5": 5, "fri": 5,
            "周六": 6, "星期六": 6, "礼拜六": 6, "周6": 6, "sat": 6,
            "周日": 7, "星期天": 7, "星期日": 7, "周天": 7, "周7": 7, "sun": 7
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var detectedWeekday = 1
            for (key, val) in weekdayMap {
                if trimmed.lowercased().contains(key) {
                    detectedWeekday = val
                    break
                }
            }

            // 识别单双周
            var weekMode = "all"
            if trimmed.contains("单周") {
                weekMode = "oddOnly"
            } else if trimmed.contains("双周") {
                weekMode = "evenOnly"
            }

            // 提取时间例如 08:30-10:05 或 8:30-10:00
            var startH = 8
            var startM = 0
            var endH = 9
            var endM = 40

            let timeRegex = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})\s*[-~至到]\s*(\d{1,2}):(\d{2})"#)
            if let match = timeRegex?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                if let shR = Range(match.range(at: 1), in: trimmed),
                   let smR = Range(match.range(at: 2), in: trimmed),
                   let ehR = Range(match.range(at: 3), in: trimmed),
                   let emR = Range(match.range(at: 4), in: trimmed) {
                    startH = Int(trimmed[shR]) ?? 8
                    startM = Int(trimmed[smR]) ?? 0
                    endH = Int(trimmed[ehR]) ?? 9
                    endM = Int(trimmed[emR]) ?? 40
                }
            }

            // 过滤提取课程名
            let tokens = trimmed.components(separatedBy: .whitespaces)
                .filter { token in
                    !token.isEmpty &&
                    !weekdayMap.keys.contains(where: { token.lowercased().contains($0) }) &&
                    !token.contains(":") && !token.contains("-") && !token.contains("周")
                }

            let courseName = tokens.first ?? "未命名课程"
            let classroom = tokens.count > 1 ? tokens[1] : ""
            let teacher = tokens.count > 2 ? tokens[2] : ""

            results.append(
                ParsedCourseDTO(
                    name: courseName,
                    classroom: classroom,
                    teacher: teacher,
                    weekday: detectedWeekday,
                    startHour: startH,
                    startMinute: startM,
                    endHour: endH,
                    endMinute: endM,
                    weekModeRaw: weekMode,
                    startWeek: 1,
                    endWeek: 16
                )
            )
        }

        return results
    }
}
