//
//  AppSettings.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation
import SwiftUI
import Security

protocol APIKeyStorage {
    func read(account: String, legacy: Bool) -> (value: String?, status: OSStatus)
    func write(_ value: String, account: String) -> Bool
}

private struct APIKeyStore: APIKeyStorage {
    #if os(macOS) && QIANYU_LOCAL_DISTRIBUTION
    // Ad hoc signatures cannot access the data protection keychain. Keep this
    // build's file-keychain items separate from development installations.
    private static let service = "com.qianyu.companion.api.local-distribution"
    #else
    private static let service = "com.qianyu.companion.api"
    #endif

    private func query(account: String, legacy: Bool = false) -> [CFString: Any] {
        var attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: account
        ]
        #if os(macOS)
        // The data protection keychain uses the signed app's access group instead of
        // a file-keychain ACL tied to a particular development build.
        #if !QIANYU_LOCAL_DISTRIBUTION
        if !legacy {
            attributes[kSecUseDataProtectionKeychain] = true
        }
        #endif
        #endif
        return attributes
    }

    func read(account: String, legacy: Bool = false) -> (value: String?, status: OSStatus) {
        var result: CFTypeRef?
        var attributes = query(account: account, legacy: legacy)
        attributes[kSecReturnData] = true
        attributes[kSecMatchLimit] = kSecMatchLimitOne
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return (nil, status)
        }
        return (String(data: data, encoding: .utf8), status)
    }

    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        let query = query(account: account)
        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        guard let data = value.data(using: .utf8) else { return false }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var attributes = query
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}

@Observable
public final class AppSettings {
    public static let shared = AppSettings()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keyStore: any APIKeyStorage
    @ObservationIgnored private var isSwitchingProvider = false
    private static let profilesKey = "qianyu_api_profiles"
    private static let keyMigrationCompleted = "qianyu_api_provider_key_migrated"
    public private(set) var configurationRevision = 0
    #if os(macOS)
    private static let legacyKeyMigrationPending = "qianyu_api_key_legacy_migration_pending"
    #endif

    // MARK: - 基础与称呼设置
    public var userName: String {
        didSet {
            defaults.set(userName, forKey: "qianyu_userName")
        }
    }

    // MARK: - 每日陪伴提醒
    public var aiDailyPushEnabled: Bool {
        didSet { defaults.set(aiDailyPushEnabled, forKey: "qianyu_ai_daily_push") }
    }
    public var weatherCity: String {
        didSet { defaults.set(weatherCity, forKey: "qianyu_weather_city") }
    }
    public var weatherUseLocation: Bool {
        didSet { defaults.set(weatherUseLocation, forKey: "qianyu_weather_use_location") }
    }
    public var duskEnabled: Bool {
        didSet { defaults.set(duskEnabled, forKey: "qianyu_dusk_enabled") }
    }
    public var duskHour: Int {
        didSet { defaults.set(duskHour, forKey: "qianyu_dusk_hour") }
    }
    public var duskMinute: Int {
        didSet { defaults.set(duskMinute, forKey: "qianyu_dusk_minute") }
    }
    public var sleepAutomationEnabled: Bool {
        didSet { defaults.set(sleepAutomationEnabled, forKey: "qianyu_sleep_automation_enabled") }
    }
    public var morningEnabled: Bool {
        didSet { defaults.set(morningEnabled, forKey: "qianyu_morning_enabled") }
    }
    public var morningHour: Int {
        didSet { defaults.set(morningHour, forKey: "qianyu_morning_hour") }
    }
    public var morningMinute: Int {
        didSet { defaults.set(morningMinute, forKey: "qianyu_morning_minute") }
    }

    public var lunchEnabled: Bool {
        didSet { defaults.set(lunchEnabled, forKey: "qianyu_lunch_enabled") }
    }
    public var lunchHour: Int {
        didSet { defaults.set(lunchHour, forKey: "qianyu_lunch_hour") }
    }
    public var lunchMinute: Int {
        didSet { defaults.set(lunchMinute, forKey: "qianyu_lunch_minute") }
    }

    public var afternoonEnabled: Bool {
        didSet { defaults.set(afternoonEnabled, forKey: "qianyu_afternoon_enabled") }
    }
    public var afternoonHour: Int {
        didSet { defaults.set(afternoonHour, forKey: "qianyu_afternoon_hour") }
    }
    public var afternoonMinute: Int {
        didSet { defaults.set(afternoonMinute, forKey: "qianyu_afternoon_minute") }
    }

    public var eveningEnabled: Bool {
        didSet { defaults.set(eveningEnabled, forKey: "qianyu_evening_enabled") }
    }
    public var eveningHour: Int {
        didSet { defaults.set(eveningHour, forKey: "qianyu_evening_hour") }
    }
    public var eveningMinute: Int {
        didSet { defaults.set(eveningMinute, forKey: "qianyu_evening_minute") }
    }

    // MARK: - 上课提醒与学期周数
    public var classReminderEnabled: Bool {
        didSet { defaults.set(classReminderEnabled, forKey: "qianyu_class_reminder_enabled") }
    }
    public var postClassReminderEnabled: Bool {
        didSet { defaults.set(postClassReminderEnabled, forKey: "qianyu_post_class_reminder_enabled") }
    }
    public var semesterStartDate: Date {
        didSet { defaults.set(semesterStartDate.timeIntervalSince1970, forKey: "qianyu_semester_start_date") }
    }

    // MARK: - 角色人设
    /// 空字符串使用随应用更新的默认人设。
    public var customPersonaPrompt: String {
        didSet { defaults.set(customPersonaPrompt, forKey: "qianyu_custom_persona_prompt") }
    }
    public var hasCustomPersonaPrompt: Bool {
        !customPersonaPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var effectivePersonaPrompt: String {
        hasCustomPersonaPrompt ? customPersonaPrompt : EditorialCopy.text("persona.base")
    }

    // MARK: - 大模型与 API 配置
    public var apiBaseURL: String {
        didSet { configurationChanged() }
    }
    public var apiKey: String {
        didSet {
            guard !isSwitchingProvider else { return }
            saveAPIKey()
            configurationChanged()
        }
    }
    public private(set) var apiKeyStorageError: String? = nil
    #if os(macOS)
    public private(set) var legacyAPIKeyNeedsMigration = false
    #endif
    public var modelName: String {
        didSet { configurationChanged() }
    }
    public var thinkingEffort: String {
        didSet { configurationChanged() }
    }
    public private(set) var selectedProviderRaw: String

    public var isLocalAPIEndpoint: Bool {
        let host = URLComponents(string: apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased()
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host ?? "")
    }
    public var isAPIConfigured: Bool {
        guard let components = URLComponents(string: apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return isLocalAPIEndpoint || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public convenience init() {
        self.init(defaults: .standard, keyStore: APIKeyStore())
    }

    /// 允许回归测试使用隔离的偏好设置与内存钥匙串。
    init(defaults: UserDefaults, keyStore: any APIKeyStorage) {
        self.defaults = defaults
        self.keyStore = keyStore
        self.userName = defaults.string(forKey: "qianyu_userName") ?? String(localized: "管理员")

        self.aiDailyPushEnabled = defaults.object(forKey: "qianyu_ai_daily_push") as? Bool ?? true
        self.weatherCity = defaults.string(forKey: "qianyu_weather_city") ?? "深圳市南山区"
        self.weatherUseLocation = defaults.bool(forKey: "qianyu_weather_use_location")
        self.duskEnabled = defaults.object(forKey: "qianyu_dusk_enabled") as? Bool ?? true
        self.duskHour = defaults.object(forKey: "qianyu_dusk_hour") as? Int ?? 18
        self.duskMinute = defaults.object(forKey: "qianyu_dusk_minute") as? Int ?? 0
        self.sleepAutomationEnabled = defaults.bool(forKey: "qianyu_sleep_automation_enabled")
        self.morningEnabled = defaults.object(forKey: "qianyu_morning_enabled") as? Bool ?? true
        self.morningHour = defaults.object(forKey: "qianyu_morning_hour") as? Int ?? 7
        self.morningMinute = defaults.object(forKey: "qianyu_morning_minute") as? Int ?? 45

        self.lunchEnabled = defaults.object(forKey: "qianyu_lunch_enabled") as? Bool ?? true
        self.lunchHour = defaults.object(forKey: "qianyu_lunch_hour") as? Int ?? 12
        self.lunchMinute = defaults.object(forKey: "qianyu_lunch_minute") as? Int ?? 0

        self.afternoonEnabled = defaults.object(forKey: "qianyu_afternoon_enabled") as? Bool ?? true
        self.afternoonHour = defaults.object(forKey: "qianyu_afternoon_hour") as? Int ?? 13
        self.afternoonMinute = defaults.object(forKey: "qianyu_afternoon_minute") as? Int ?? 45

        self.eveningEnabled = defaults.object(forKey: "qianyu_evening_enabled") as? Bool ?? true
        self.eveningHour = defaults.object(forKey: "qianyu_evening_hour") as? Int ?? 22
        self.eveningMinute = defaults.object(forKey: "qianyu_evening_minute") as? Int ?? 30

        self.classReminderEnabled = defaults.object(forKey: "qianyu_class_reminder_enabled") as? Bool ?? true
        self.postClassReminderEnabled = defaults.object(forKey: "qianyu_post_class_reminder_enabled") as? Bool ?? true

        // 未配置时选择最近一次春季或秋季开学日期。
        let savedSemesterTimestamp = defaults.double(forKey: "qianyu_semester_start_date")
        if savedSemesterTimestamp > 0 {
            self.semesterStartDate = Date(timeIntervalSince1970: savedSemesterTimestamp)
        } else {
            let now = Date()
            let year = Calendar.current.component(.year, from: now)
            let spring = Calendar.current.date(from: DateComponents(year: year, month: 2, day: 20)) ?? now
            let fall = Calendar.current.date(from: DateComponents(year: year, month: 9, day: 1)) ?? now
            let previousFall = Calendar.current.date(from: DateComponents(year: year - 1, month: 9, day: 1)) ?? now
            self.semesterStartDate = now >= fall ? fall : (now >= spring ? spring : previousFall)
        }

        self.customPersonaPrompt = defaults.string(forKey: "qianyu_custom_persona_prompt") ?? ""
        let initialProvider = defaults.string(forKey: "qianyu_selected_provider") ?? "deepseek"
        self.selectedProviderRaw = initialProvider
        let profiles = defaults.dictionary(forKey: Self.profilesKey) as? [String: [String: String]] ?? [:]
        let profile = profiles[initialProvider]
        self.apiBaseURL = profile?["url"] ?? defaults.string(forKey: "qianyu_api_base_url") ?? "https://api.deepseek.com/chat/completions"
        self.modelName = profile?["model"] ?? defaults.string(forKey: "qianyu_model_name") ?? "deepseek-flash"
        let savedEffort = profile?["effort"] ?? defaults.string(forKey: "qianyu_thinking_effort") ?? "auto"
        // 旧版 none 只设置 temperature，并未真正关闭推理；升级后按模型默认行为处理。
        self.thinkingEffort = profile == nil && savedEffort == "none" ? "auto" : savedEffort
        self.apiKey = ""
        loadAPIKey(allowMigration: !defaults.bool(forKey: Self.keyMigrationCompleted))
        persistCurrentProfile()
    }

    private var keyAccount: String { "chat-api-key.\(selectedProviderRaw)" }

    private func configurationChanged() {
        guard !isSwitchingProvider else { return }
        persistCurrentProfile()
        configurationRevision &+= 1
    }

    private func persistCurrentProfile() {
        var profiles = defaults.dictionary(forKey: Self.profilesKey) as? [String: [String: String]] ?? [:]
        profiles[selectedProviderRaw] = ["url": apiBaseURL, "model": modelName, "effort": thinkingEffort]
        defaults.set(profiles, forKey: Self.profilesKey)
        defaults.set(selectedProviderRaw, forKey: "qianyu_selected_provider")
        // 保留旧字段，确保已有读取方和升级路径仍然一致。
        defaults.set(apiBaseURL, forKey: "qianyu_api_base_url")
        defaults.set(modelName, forKey: "qianyu_model_name")
        defaults.set(thinkingEffort, forKey: "qianyu_thinking_effort")
    }

    private func saveAPIKey() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyStore.write(value, account: keyAccount) else {
            apiKeyStorageError = String(localized: "API Key 未能保存到钥匙串，请重试。当前输入仅在本次运行中有效。")
            return
        }
        apiKeyStorageError = nil
        defaults.set(true, forKey: Self.keyMigrationCompleted)
        defaults.removeObject(forKey: "qianyu_api_key")
        #if os(macOS)
        legacyAPIKeyNeedsMigration = false
        defaults.removeObject(forKey: Self.legacyKeyMigrationPending)
        #endif
    }

    public func retryAPIKeySave() { saveAPIKey() }

    private func loadAPIKey(allowMigration: Bool) {
        let wasSwitching = isSwitchingProvider
        isSwitchingProvider = true
        defer { isSwitchingProvider = wasSwitching }
        apiKeyStorageError = nil
        #if os(macOS)
        legacyAPIKeyNeedsMigration = false
        #endif
        let result = keyStore.read(account: keyAccount, legacy: false)
        apiKey = result.value ?? ""
        if result.status != errSecSuccess && result.status != errSecItemNotFound {
            apiKeyStorageError = String(localized: "无法读取钥匙串中的 API Key，请解锁系统钥匙串后重试。")
            return
        }
        if result.value != nil {
            defaults.set(true, forKey: Self.keyMigrationCompleted)
            return
        }
        if !allowMigration { return }

        let legacyResult = keyStore.read(account: "chat-api-key", legacy: false)
        if let value = legacyResult.value {
            apiKey = value
            saveAPIKey()
            return
        }
        if let value = defaults.string(forKey: "qianyu_api_key"), !value.isEmpty {
            apiKey = value
            saveAPIKey()
            return
        }
        if legacyResult.status != errSecItemNotFound {
            apiKeyStorageError = String(localized: "旧 API Key 暂时无法读取，请解锁系统钥匙串后重试。")
            return
        }
        #if os(macOS)
        if defaults.bool(forKey: Self.legacyKeyMigrationPending) {
            legacyAPIKeyNeedsMigration = true
        } else {
            let oldResult = keyStore.read(account: "chat-api-key", legacy: true)
            if let value = oldResult.value {
                apiKey = value
                saveAPIKey()
                legacyAPIKeyNeedsMigration = apiKeyStorageError != nil
            } else if oldResult.status != errSecItemNotFound {
                legacyAPIKeyNeedsMigration = true
            }
        }
        if legacyAPIKeyNeedsMigration {
            defaults.set(true, forKey: Self.legacyKeyMigrationPending)
            apiKeyStorageError = String(localized: "旧 API Key 尚未迁移。可允许一次旧钥匙串访问，或重新输入 API Key。")
            return
        }
        #endif
        defaults.set(true, forKey: Self.keyMigrationCompleted)
    }

    /// 切换服务商时分别保存地址、手动模型、思考设置和密钥；重复选择不重置。
    @discardableResult
    public func activateProvider(code: String, defaultURL: String, defaultModel: String) -> Bool {
        guard code != selectedProviderRaw else { return true }
        if apiKeyStorageError != nil && !apiKey.isEmpty {
            saveAPIKey()
            guard apiKeyStorageError == nil else { return false }
        }
        persistCurrentProfile()
        let profiles = defaults.dictionary(forKey: Self.profilesKey) as? [String: [String: String]] ?? [:]
        let profile = profiles[code]
        isSwitchingProvider = true
        selectedProviderRaw = code
        apiBaseURL = profile?["url"] ?? defaultURL
        modelName = profile?["model"] ?? defaultModel
        thinkingEffort = profile?["effort"] ?? "auto"
        loadAPIKey(allowMigration: false)
        isSwitchingProvider = false
        configurationChanged()
        return true
    }

    public func reloadAPIKey() {
        loadAPIKey(allowMigration: !defaults.bool(forKey: Self.keyMigrationCompleted))
        configurationRevision &+= 1
    }

    #if os(macOS)
    public func retryLegacyAPIKeyMigration() {
        let result = keyStore.read(account: "chat-api-key", legacy: true)
        guard let oldKey = result.value else {
            apiKeyStorageError = result.status == errSecItemNotFound
                ? String(localized: "旧钥匙串中没有找到 API Key，请重新输入。")
                : String(localized: "未能读取旧 API Key，请允许本次钥匙串访问或重新输入。")
            return
        }
        apiKey = oldKey
    }
    #endif

    // MARK: - 学期周数与单双周计算
    /// 计算指定日期属于学期的第几周 (从 1 开始，严格按照周一至周日完整教学周推进)
    public func currentWeekNumber(from date: Date = Date()) -> Int {
        CourseTimeRules.displayWeek(on: date, semesterStart: semesterStartDate,
                                    calendar: Calendar(identifier: .gregorian))
    }

    /// 指定日期是否属于单周
    public func isCurrentWeekOdd(from date: Date = Date()) -> Bool {
        return currentWeekNumber(from: date) % 2 != 0
    }

    public var currentWeekDisplay: String {
        let week = currentWeekNumber()
        let oddText = isCurrentWeekOdd() ? String(localized: "单周") : String(localized: "双周")
        return String(localized: "第 \(week) 周 · \(oddText)")
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
        case .dusk:
            self.duskHour = hour
            self.duskMinute = minute
        case .evening:
            self.eveningHour = hour
            self.eveningMinute = minute
        }
    }
}

public enum PushType {
    case dusk
    case morning, lunch, afternoon, evening
}
