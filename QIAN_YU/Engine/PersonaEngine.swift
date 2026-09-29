//
//  PersonaEngine.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation

public struct PersonaEngine {
    public static let shared = PersonaEngine()
    private let settings: AppSettings

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    /// 每次请求都读取已保存的人设；未自定义时使用 EditorialContent.json 的默认设定。
    public var baseSystemPrompt: String { settings.effectivePersonaPrompt }

    /// 构建注入当前时间、今日课程与用户称呼的动态提示词
    public func buildSystemPrompt(
        userName: String = "管理员",
        upcomingCourseHint: String? = nil,
        weatherHint: String? = nil
    ) -> String {
        if settings.hasCustomPersonaPrompt {
            return buildCustomSystemPrompt(
                userName: userName,
                upcomingCourseHint: upcomingCourseHint,
                weatherHint: weatherHint
            )
        }

        let hour = Calendar.current.component(.hour, from: Date())
        var timeContext = ""

        switch hour {
        case 5..<11:
            timeContext = EditorialCopy.text("persona.time.morning")
        case 11..<14:
            timeContext = EditorialCopy.text("persona.time.lunch")
        case 14..<18:
            timeContext = EditorialCopy.text("persona.time.afternoon")
        case 18..<22:
            timeContext = EditorialCopy.text("persona.time.evening")
        default:
            timeContext = EditorialCopy.text("persona.time.night")
        }

        var prompt = EditorialCopy.text("persona.context", [
            "base": baseSystemPrompt, "userName": userName, "timeContext": timeContext
        ])

        if let course = upcomingCourseHint, !course.isEmpty {
            prompt += EditorialCopy.text("persona.course", ["course": course])
        }

        if let weather = weatherHint, !weather.isEmpty {
            prompt += EditorialCopy.text("persona.weather", ["weather": weather])
        }

        return prompt
    }

    /// 自定义人设只补充事实背景，避免默认时段台词中的语气、行为要求覆盖用户设定。
    private func buildCustomSystemPrompt(
        userName: String,
        upcomingCourseHint: String?,
        weatherHint: String?
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var prompt = baseSystemPrompt + "\n\n【实时情境信息，仅作为背景】：\n对方称呼：\(userName)\n当前本地时间：\(formatter.string(from: Date()))"
        if let course = upcomingCourseHint, !course.isEmpty {
            prompt += "\n【课表动态】：\(course)"
        }
        if let weather = weatherHint, !weather.isEmpty {
            prompt += "\n【天气概况】：\(weather)"
        }
        return prompt
    }

    /// 离线每日推送保底文案库 (严格符合千语口吻)
    public func fallbackNotification(for type: PushType, userName: String = "管理员") -> (title: String, body: String) {
        let key: String
        switch type {
        case .morning: key = "morning"
        case .lunch: key = "lunch"
        case .afternoon: key = "afternoon"
        case .evening: key = "evening"
        }
        return (
            EditorialCopy.text("notification.\(key).title", ["userName": userName]),
            EditorialCopy.text("notification.\(key).body", ["userName": userName])
        )
    }
}
