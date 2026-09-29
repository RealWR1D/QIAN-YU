//
//  DailyPushSettingsView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct DailyPushSettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @Bindable public var scheduleViewModel: CourseScheduleViewModel

    public init(viewModel: SettingsViewModel, scheduleViewModel: CourseScheduleViewModel) {
        self.viewModel = viewModel
        self.scheduleViewModel = scheduleViewModel
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

                            Text(viewModel.isAuthorizedForNotification ? "千语将按设定时间准时在状态栏或屏幕为你推送上课与日常问候。" : "开启后千语才能在课前和每日定点给你发通知。")
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

                // 2. 每日四大定点陪伴推送
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSectionHeader(title: String(localized: "千语每日陪伴定点推送"), icon: "clock.badge.checkmark")

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

                    Text("推送时间到达时，系统将以陈千语专属口吻发送带有横幅与声音的本地通知。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

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
