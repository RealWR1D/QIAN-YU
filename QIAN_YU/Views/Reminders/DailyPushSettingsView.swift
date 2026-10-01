//
//  DailyPushSettingsView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct DailyPushSettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @State private var weatherCityQuery = ""
    @State private var weather = DailyWeatherService.shared
    @Bindable public var scheduleViewModel: CourseScheduleViewModel

    public init(viewModel: SettingsViewModel, scheduleViewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
        self.scheduleViewModel = scheduleViewModel
        self._weatherCityQuery = State(initialValue: viewModel.settings.weatherCity)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 权限状态横幅
                SettingsCardContainer {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill((viewModel.isAuthorizedForNotification ? Color.green : Color.orange).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: viewModel.isAuthorizedForNotification ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.system(size: 18))
                                .foregroundColor(viewModel.isAuthorizedForNotification ? .green : .orange)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(viewModel.isAuthorizedForNotification ? "系统通知权限已开启" : "系统通知权限未开启")
                                .font(.system(size: 14, weight: .bold))

                            Text(viewModel.isAuthorizedForNotification ? "千语会根据课表和提醒规则发送上课与日常问候。" : "开启后千语才能发送课程与每日提醒。")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !viewModel.isAuthorizedForNotification {
                            Button("去授权") {
                                Task {
                                    await viewModel.requestNotificationPermission()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                    .padding(16)
                }

                // 2. 每日五个时段的陪伴推送
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "千语每日陪伴推送"), icon: "clock.badge.checkmark")

                    SettingsCardContainer {
                        // 晨醒
                        DailyPushRow(
                            icon: "🌅",
                            title: String(localized: "清晨唤醒"),
                            isEnabled: $viewModel.settings.morningEnabled,
                            hour: viewModel.settings.morningHour,
                            minute: viewModel.settings.morningMinute,
                            quote: EditorialCopy.text("notification.morning.body"),
                            onTimeChange: { date in
                                viewModel.settings.update(type: .morning, from: date)
                                viewModel.updateDailySchedules()
                            }
                        )

                        Divider().padding(.leading, 16)

                        // 午饭
                        DailyPushRow(
                            icon: "🍱",
                            title: String(localized: "午饭提醒"),
                            isEnabled: $viewModel.settings.lunchEnabled,
                            hour: viewModel.settings.lunchHour,
                            minute: viewModel.settings.lunchMinute,
                            quote: EditorialCopy.text("notification.lunch.body"),
                            onTimeChange: { date in
                                viewModel.settings.update(type: .lunch, from: date)
                                viewModel.updateDailySchedules()
                            }
                        )

                        Divider().padding(.leading, 16)

                        // 午后放松
                        DailyPushRow(
                            icon: "💆",
                            title: String(localized: "午后防困与穴位放松"),
                            isEnabled: $viewModel.settings.afternoonEnabled,
                            hour: viewModel.settings.afternoonHour,
                            minute: viewModel.settings.afternoonMinute,
                            quote: EditorialCopy.text("notification.afternoon.body"),
                            onTimeChange: { date in
                                viewModel.settings.update(type: .afternoon, from: date)
                                viewModel.updateDailySchedules()
                            }
                        )

                        Divider().padding(.leading, 16)

                        DailyPushRow(
                            icon: "🌇",
                            title: String(localized: "傍晚鼓励"),
                            isEnabled: $viewModel.settings.duskEnabled,
                            hour: viewModel.settings.duskHour,
                            minute: viewModel.settings.duskMinute,
                            quote: EditorialCopy.text("notification.dusk.body"),
                            onTimeChange: { date in
                                viewModel.settings.update(type: .dusk, from: date)
                                viewModel.updateDailySchedules()
                            }
                        )
                        Divider().padding(.leading, 16)

                        // 晚间就寝
                        DailyPushRow(
                            icon: "🌙",
                            title: String(localized: "深夜就寝"),
                            isEnabled: $viewModel.settings.eveningEnabled,
                            hour: viewModel.settings.eveningHour,
                            minute: viewModel.settings.eveningMinute,
                            quote: EditorialCopy.text("notification.evening.body"),
                            onTimeChange: { date in
                                viewModel.settings.update(type: .evening, from: date)
                                viewModel.updateDailySchedules()
                            }
                        )
                    }

                    Text("午饭：上午最后一节课早于 11:00 结束时，11:30 提醒；11:00 或之后结束时，下课即提醒。没有上午课时使用上方时间。午后：仅在 14:00–15:00 有课时提醒。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    Text("所有提醒使用普通通知，声音和横幅由系统通知与专注模式设置决定。每日提醒预排未来 7 天，打开应用或运行睡眠自动化时续排，系统后台刷新也会尝试续排。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "AI 问候与天气"), icon: "sparkles")
                    SettingsCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("用 AI 生成每日问候", isOn: $viewModel.settings.aiDailyPushEnabled)
                                .onChange(of: viewModel.settings.aiDailyPushEnabled) { _, _ in viewModel.updateDailySchedules() }
                            Text("使用已配置的 API，自动生成可能产生费用。早晨结合天气预报，午饭结合当天课程时长，傍晚结合剩余课程；就寝只说晚安。会检查正文重复，无法生成时使用可变的本地文案。")
                            Text("文案在打开应用或系统允许后台刷新时提前准备，通知到点直接发送缓存内容。天气是指定日期的预报；没有可靠数据就不提天气。")
                            Divider()
                            TextField("常用城市 / 区，例如深圳市南山区", text: $weatherCityQuery)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Button("查找城市与区") {
                                    Task { await weather.search(city: weatherCityQuery) }
                                }
                                Button("使用当前位置") { Task { await weather.useCurrentLocation() } }
                            }
                            Text("常用地点：\(viewModel.settings.weatherCity)").foregroundStyle(.secondary)
                            Toggle("优先使用已获取的当前位置", isOn: $viewModel.settings.weatherUseLocation)
                                .onChange(of: viewModel.settings.weatherUseLocation) { _, _ in viewModel.updateDailySchedules() }
                            ForEach(Array(weather.places.enumerated()), id: \.offset) { _, place in
                                Button(DailyWeatherService.name(place)) {
                                    weather.select(place)
                                    weatherCityQuery = viewModel.settings.weatherCity
                                }
                            }
                            if !weather.status.isEmpty { Text(weather.status).foregroundStyle(.secondary) }
                            Text("只在你点击「使用当前位置」时申请使用期间定位。定位被拒绝、撤销或超过一天未更新时使用常用城市；修改城市后请查找并选择地点。城市、区名可用于查找，不需要精确定位。天气由 Open-Meteo 提供，天气服务会收到所选地点的坐标；AI 收到天气概况、课程统计、称呼、角色设定和近期通知正文，不发送精确坐标、街道地址或聊天记录。")
                            Link("天气来源：Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                        }
                        .font(.system(size: 12))
                        .padding(16)
                    }
                }

                #if os(iOS)
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "跟随睡眠模式"), icon: "moon.zzz")
                    SettingsCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("已配置睡眠自动化", isOn: $viewModel.settings.sleepAutomationEnabled)
                                .onChange(of: viewModel.settings.sleepAutomationEnabled) { _, _ in
                                    viewModel.updateDailySchedules()
                                }
                            Text("在 iPhone「快捷指令 → 自动化」中创建两项个人自动化，触发条件均选择「睡眠」专注模式，并选择「立即运行」：")
                            Text("① 关闭时：添加千语的「睡眠已结束」动作。\n② 开启时：添加千语的「准备睡觉」动作。\n两项配置完成后，再开启上方开关。")
                            Text("开启后，清晨优先在退出睡眠模式时提醒，最迟在设定时间后一小时提醒；晚安优先在进入睡眠模式时提醒，最迟在设定时间提醒。每天各一次，超过截止时间不再补发。清晨动作在上午生效，晚安按当次就寝的截止时间判断，支持跨午夜。未开启时，早晚按设定时间提醒。")
                        }
                        .font(.system(size: 12))
                        .padding(16)
                    }
                }
                #endif

                // 3. 上课提醒与学期周数
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "上课提醒与学期教学周"), icon: "book.closed")

                    SettingsCardContainer {
                        // 课前预警
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("启用课前千语智能通知")
                                    .font(.system(size: 14, weight: .medium))

                                Text("当课表中课程开启提醒时，千语将在课前提前为你预警教室与时间")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.settings.classReminderEnabled)
                                .labelsHidden()
                                .onChange(of: viewModel.settings.classReminderEnabled) { _, isEnabled in
                                    CourseReminderService.shared.syncAllCourseReminders(courses: scheduleViewModel.courses)
                                }
                        }
                        .padding(16)

                        Divider().padding(.leading, 16)

                        // 课后收尾关怀
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("启用课后千语收尾关怀")
                                    .font(.system(size: 14, weight: .medium))

                                Text("下课时千语主动提醒收拾文具、喝水活动、或根据下节课距离为你预留赶路时间")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.settings.postClassReminderEnabled)
                                .labelsHidden()
                                .onChange(of: viewModel.settings.postClassReminderEnabled) { _, isEnabled in
                                    CourseReminderService.shared.syncAllCourseReminders(courses: scheduleViewModel.courses)
                                }
                        }
                        .padding(16)

                        Divider().padding(.leading, 16)

                        // 开学第一周日期与周数推算
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("开学第一周起始日期")
                                    .font(.system(size: 14, weight: .medium))

                                Text("系统已判定当前为【\(viewModel.settings.currentWeekDisplay)】，用于单双周智能过滤")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            DatePicker(
                                "",
                                selection: $viewModel.settings.semesterStartDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                        .padding(16)
                        .onChange(of: viewModel.settings.semesterStartDate) { _, _ in
                            scheduleViewModel.selectedWeek = AppSettings.shared.currentWeekNumber()
                            scheduleViewModel.updateWidgetSnapshot()
                            CourseReminderService.shared.syncAllCourseReminders(courses: scheduleViewModel.courses)
                        }
                    }
                }

                // 4. 即刻体验测试
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "推送测试"), icon: "paperplane")

                    SettingsCardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("即刻体验通知效果")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("点击后 3 秒触发本地通知横幅，便于测试系统声音与权限。")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.triggerTestPush()
                                } label: {
                                    Label("发送测试通知", systemImage: "paperplane.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color.orange)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            if !viewModel.testNotificationMessage.isEmpty {
                                Text(viewModel.testNotificationMessage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.qianyuSettingsBg)
        .navigationTitle("每日推送与提醒")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.checkPermissions()
        }
    }
}

// MARK: - 单条推送设置行组件
struct DailyPushRow: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool
    let hour: Int
    let minute: Int
    let quote: String
    let onTimeChange: (Date) -> Void

    private var timeDate: Date {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = hour
        comp.minute = minute
        return Calendar.current.date(from: comp) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text(icon)
                        .font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                }

                Spacer()

                DatePicker(
                    "",
                    selection: Binding(
                        get: { timeDate },
                        set: { onTimeChange($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .disabled(!isEnabled)

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _, _ in
                        onTimeChange(timeDate)
                    }
            }

            Text(quote)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
