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

    /// 构建注入当前时间、完整课表与用户称呼的动态提示词。
    public func buildSystemPrompt(
        userName: String = "管理员",
        upcomingCourseHint: String? = nil,
        scheduleContext: String? = nil,
        weatherHint: String? = nil
    ) -> String {
        // 默认与自定义人设都只附加事实，避免时段台词强制角色催睡、劝饭。
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var prompt = EditorialCopy.text("persona.context", [
            "base": baseSystemPrompt,
            "userName": userName,
            "timeContext": "当前本地时间：\(formatter.string(from: Date()))"
        ])

        if let course = upcomingCourseHint, !course.isEmpty {
            prompt += EditorialCopy.text("persona.course", ["course": course])
        }

        if let schedule = scheduleContext, !schedule.isEmpty {
            prompt += EditorialCopy.text("persona.schedule", ["schedule": schedule])
        }

        if let weather = weatherHint, !weather.isEmpty {
            prompt += EditorialCopy.text("persona.weather", ["weather": weather])
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
        case .dusk: key = "dusk"
        case .evening: key = "evening"
        }
        return (
            EditorialCopy.text("notification.\(key).title", ["userName": userName]),
            EditorialCopy.text("notification.\(key).body", ["userName": userName])
        )
    }
}
