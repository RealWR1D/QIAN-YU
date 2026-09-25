//
//  MainView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData

public enum AppTab: String, CaseIterable, Identifiable {
    case companion = "千语伴行"
    case schedule = "课程表"
    case focus = "专注番茄钟"
    case settings = "设置"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .companion: return "sparkles"
        case .schedule: return "calendar"
        case .focus: return "timer"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainView: View {
    @State private var selectedTab: AppTab = .companion
    @State public var scheduleViewModel: CourseScheduleViewModel
    @State public var settingsViewModel = SettingsViewModel()
    @Environment(\.modelContext) private var modelContext

    public init(scheduleViewModel: CourseScheduleViewModel? = nil) {
        self._scheduleViewModel = State(initialValue: scheduleViewModel ?? CourseScheduleViewModel())
    }

    public var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                ChatView(scheduleViewModel: scheduleViewModel)
            }
            .tabItem {
                Label(AppTab.companion.rawValue, systemImage: AppTab.companion.iconName)
            }
            .tag(AppTab.companion)

            NavigationStack {
                CourseScheduleView(viewModel: scheduleViewModel)
            }
            .tabItem {
                Label(AppTab.schedule.rawValue, systemImage: AppTab.schedule.iconName)
            }
            .tag(AppTab.schedule)

            NavigationStack {
                PomodoroTimerView()
            }
            .tabItem {
                Label(AppTab.focus.rawValue, systemImage: AppTab.focus.iconName)
            }
            .tag(AppTab.focus)

            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.iconName)
            }
            .tag(AppTab.settings)
        }
        .tint(.orange)
        .task {
            scheduleViewModel.setContext(modelContext)
            _ = await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.scheduleDailyNotifications()
        }
        #else
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("功能导航") {
                    ForEach(AppTab.allCases) { tab in
                        HStack(spacing: 12) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .orange : .secondary)
                                .frame(width: 24, height: 24, alignment: .center)

                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .primary : .primary.opacity(0.85))

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .tag(tab)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("千语伴行")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        selectedTab = .companion
                    } label: {
                        HStack(spacing: 10) {
                            // 1. 头像 + 在线状态角标（原生角标层叠，彻底避免挤占文字宽度）
                            ZStack(alignment: .bottomTrailing) {
                                Image("QianyuAvatar")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.orange.opacity(0.85), Color.yellow.opacity(0.85)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color.orange.opacity(0.18), radius: 2, x: 0, y: 1)

                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 9, height: 9)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                                    )
                                    .offset(x: 1, y: 1)
                            }

                            // 2. 角色信息文本（强制单行，彻底杜绝任何折行或上下错位）
                            VStack(alignment: .leading, spacing: 2) {
                                Text("陈千语")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text("特勤干员 · 随行中")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.orange.opacity(selectedTab == .companion ? 0.12 : 0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.orange.opacity(selectedTab == .companion ? 0.35 : 0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            }
        } detail: {
            Group {
                switch selectedTab {
                case .companion:
                    ChatView(scheduleViewModel: scheduleViewModel)
                case .schedule:
                    CourseScheduleView(viewModel: scheduleViewModel)
                case .focus:
                    PomodoroTimerView()
                case .settings:
                    NavigationStack {
                        SettingsView(viewModel: settingsViewModel)
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 450)
        }
        .tint(.orange)
        .task {
            scheduleViewModel.setContext(modelContext)
            _ = await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.scheduleDailyNotifications()
        }
        #endif
    }
}
