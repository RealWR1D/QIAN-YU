//
//  AppSettings.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI

@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - 基础与称呼设置
    public var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "qianyu_userName") }
    }

    // MARK: - 每日四大定点提醒开关与时间
    public var morningEnabled: Bool {
        didSet { UserDefaults.standard.set(morningEnabled, forKey: "qianyu_morning_enabled") }
    }
    public var morningHour: Int {
        didSet { UserDefaults.standard.set(morningHour, forKey: "qianyu_morning_hour") }
    }
    public var morningMinute: Int {
        didSet { UserDefaults.standard.set(morningMinute, forKey: "qianyu_morning_minute") }
    }

    public var lunchEnabled: Bool {
        didSet { UserDefaults.standard.set(lunchEnabled, forKey: "qianyu_lunch_enabled") }
    }
    public var lunchHour: Int {
        didSet { UserDefaults.standard.set(lunchHour, forKey: "qianyu_lunch_hour") }
    }
    public var lunchMinute: Int {
        didSet { UserDefaults.standard.set(lunchMinute, forKey: "qianyu_lunch_minute") }
    }

    public var afternoonEnabled: Bool {
        didSet { UserDefaults.standard.set(afternoonEnabled, forKey: "qianyu_afternoon_enabled") }
    }
    public var afternoonHour: Int {
        didSet { UserDefaults.standard.set(afternoonHour, forKey: "qianyu_afternoon_hour") }
    }
    public var afternoonMinute: Int {
        didSet { UserDefaults.standard.set(afternoonMinute, forKey: "qianyu_afternoon_minute") }
    }

    public var eveningEnabled: Bool {
        didSet { UserDefaults.standard.set(eveningEnabled, forKey: "qianyu_evening_enabled") }
    }
    public var eveningHour: Int {
        didSet { UserDefaults.standard.set(eveningHour, forKey: "qianyu_evening_hour") }
    }
    public var eveningMinute: Int {
        didSet { UserDefaults.standard.set(eveningMinute, forKey: "qianyu_evening_minute") }
    }

    // MARK: - 上课提醒与学期周数
    public var classReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(classReminderEnabled, forKey: "qianyu_class_reminder_enabled") }
    }
    public var postClassReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(postClassReminderEnabled, forKey: "qianyu_post_class_reminder_enabled") }
    }
    public var semesterStartDate: Date {
        didSet { UserDefaults.standard.set(semesterStartDate.timeIntervalSince1970, forKey: "qianyu_semester_start_date") }
    }

    // MARK: - 大模型与 API 配置
    public var apiBaseURL: String {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: "qianyu_api_base_url") }
    }
    public var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "qianyu_api_key") }
    }
    public var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: "qianyu_model_name") }
    }
    public var thinkingEffort: String {
        didSet { UserDefaults.standard.set(thinkingEffort, forKey: "qianyu_thinking_effort") }
    }
    public var selectedProviderRaw: String {
        didSet { UserDefaults.standard.set(selectedProviderRaw, forKey: "qianyu_selected_provider") }
    }

    public init() {
        let defaults = UserDefaults.standard
        self.userName = defaults.string(forKey: "qianyu_userName") ?? "管理员"

        self.morningEnabled = defaults.object(forKey: "qianyu_morning_enabled") as? Bool ?? true
        self.morningHour = defaults.object(forKey: "qianyu_morning_hour") as? Int ?? 7
        self.morningMinute = defaults.object(forKey: "qianyu_morning_minute") as? Int ?? 45

        self.lunchEnabled = defaults.object(forKey: "qianyu_lunch_enabled") as? Bool ?? true
        self.lunchHour = defaults.object(forKey: "qianyu_lunch_hour") as? Int ?? 12
        self.lunchMinute = defaults.object(forKey: "qianyu_lunch_minute") as? Int ?? 0

        self.afternoonEnabled = defaults.object(forKey: "qianyu_afternoon_enabled") as? Bool ?? true
        self.afternoonHour = defaults.object(forKey: "qianyu_afternoon_hour") as? Int ?? 14
        self.afternoonMinute = defaults.object(forKey: "qianyu_afternoon_minute") as? Int ?? 0

        self.eveningEnabled = defaults.object(forKey: "qianyu_evening_enabled") as? Bool ?? true
        self.eveningHour = defaults.object(forKey: "qianyu_evening_hour") as? Int ?? 22
        self.eveningMinute = defaults.object(forKey: "qianyu_evening_minute") as? Int ?? 30

        self.classReminderEnabled = defaults.object(forKey: "qianyu_class_reminder_enabled") as? Bool ?? true
        self.postClassReminderEnabled = defaults.object(forKey: "qianyu_post_class_reminder_enabled") as? Bool ?? true

        // 默认开学日期为当年 9 月第一个周一或当前学期起始
        let savedSemesterTimestamp = defaults.double(forKey: "qianyu_semester_start_date")
        if savedSemesterTimestamp > 0 {
            self.semesterStartDate = Date(timeIntervalSince1970: savedSemesterTimestamp)
        } else {
            // 默认设置为当年/最近的 9 月 1 日或 2 月 20 日
            var comp = Calendar.current.dateComponents([.year], from: Date())
            comp.month = 9
            comp.day = 1
            self.semesterStartDate = Calendar.current.date(from: comp) ?? Date()
        }

        self.apiBaseURL = defaults.string(forKey: "qianyu_api_base_url") ?? "https://api.deepseek.com/chat/completions"
        self.apiKey = defaults.string(forKey: "qianyu_api_key") ?? ""
        self.modelName = defaults.string(forKey: "qianyu_model_name") ?? "deepseek-chat"
        self.thinkingEffort = defaults.string(forKey: "qianyu_thinking_effort") ?? "none"
        self.selectedProviderRaw = defaults.string(forKey: "qianyu_selected_provider") ?? "deepseek"
    }

    // MARK: - 学期周数与单双周计算
    /// 计算指定日期属于学期的第几周 (从 1 开始，严格按照周一至周日完整教学周推进)
    public func currentWeekNumber(from date: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 强制周一为每周起始日
        let semesterMonday = calendar.dateInterval(of: .weekOfYear, for: semesterStartDate)?.start ?? calendar.startOfDay(for: semesterStartDate)
        let targetMonday = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let diffDays = calendar.dateComponents([.day], from: semesterMonday, to: targetMonday).day ?? 0
        if diffDays < 0 {
            return 1 // 开学前默认当第1周
        }
        let week = (diffDays / 7) + 1
        return max(1, min(week, 35))
    }

    /// 指定日期是否属于单周
    public func isCurrentWeekOdd(from date: Date = Date()) -> Bool {
        return currentWeekNumber(from: date) % 2 != 0
    }

    public var currentWeekDisplay: String {
        let week = currentWeekNumber()
        let oddText = isCurrentWeekOdd() ? "单周" : "双周"
        return "第 \(week) 周 · \(oddText)"
    }

    // MARK: - DatePicker 转换辅助
    public func dateFor(hour: Int, minute: Int) -> Date {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = hour
        comp.minute = minute
        return Calendar.current.date(from: comp) ?? Date()
    }

    public func update(type: PushType, from date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        switch type {
        case .morning:
            self.morningHour = hour
            self.morningMinute = minute
        case .lunch:
            self.lunchHour = hour
            self.lunchMinute = minute
        case .afternoon:
            self.afternoonHour = hour
            self.afternoonMinute = minute
        case .evening:
            self.eveningHour = hour
            self.eveningMinute = minute
        }
    }
}

public enum PushType {
    case morning, lunch, afternoon, evening
}

public enum ThinkingEffortOption: String, CaseIterable, Identifiable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "关闭 (极速直答，推荐)"
        case .low: return "低 (快速思考)"
        case .medium: return "中 (平衡思考)"
        case .high: return "高 (深度推理)"
        }
    }
}
