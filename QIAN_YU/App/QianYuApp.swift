//
//  QianYuApp.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
import SwiftData

@main
struct QianYuApp: App {
    let container: ModelContainer
    @State private var sharedScheduleViewModel = CourseScheduleViewModel()
    @State private var sharedPomodoroViewModel = PomodoroTimerViewModel()

    init() {
        let schema = Schema([
            ChatMessage.self,
            CourseItem.self
        ])

        // 尝试启用 CloudKit 自动私有云同步；若当前环境未登录 iCloud 或未开通，自动平滑降级为本地存储，保证 100% 稳定不崩溃
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)]
        ) {
            self.container = cloudContainer
        } else {
            do {
                let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                self.container = try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("无法初始化 SwiftData ModelContainer: \(error)")
            }
        }

        #if os(macOS)
        // 动态强制应用 Dock 官方圆角图标（带标准 macOS 连续曲率圆角与微阴影）
        let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns")
        if let path = iconPath, let iconImage = NSImage(contentsOfFile: path) {
            NSApplication.shared.applicationIconImage = iconImage
        } else if let iconImage = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = iconImage
        }
        #endif
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView(scheduleViewModel: sharedScheduleViewModel, pomodoroViewModel: sharedPomodoroViewModel)
                .modelContainer(container)
                .onAppear {
                    sharedScheduleViewModel.setContext(container.mainContext)
                    sharedScheduleViewModel.updateWidgetSnapshot()
                    #if os(macOS)
                    let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns")
                    if let path = iconPath, let iconImage = NSImage(contentsOfFile: path) {
                        NSApplication.shared.applicationIconImage = iconImage
                    } else if let iconImage = NSImage(named: "AppIcon") {
                        NSApplication.shared.applicationIconImage = iconImage
                    }
                    #endif
                }
                .onOpenURL { url in
                    NSLog("📢 [QianYuApp] Received openURL: %@", url.absoluteString)
                    if url.scheme == "qianyu" {
                        let host = url.host ?? ""
                        if host == "startPomodoro" || host == "testLiveActivity" || url.path.contains("startPomodoro") {
                            #if os(iOS)
                            let res = LiveActivityManager.shared.startPomodoro(
                                sessionTitle: "专注中",
                                totalSeconds: 25 * 60,
                                remainingSeconds: 25 * 60,
                                quote: "「当破即破，冲冲冲！」"
                            )
                            NSLog("📢 [QianYuApp] startPomodoro result: %d", res ? 1 : 0)
                            #endif
                        } else if host == "stopPomodoro" || url.path.contains("stopPomodoro") {
                            #if os(iOS)
                            LiveActivityManager.shared.endPomodoro()
                            #endif
                        }
                    }
                }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh("com.qianyu.companion.course-reminder-refresh")) {
            CourseReminderBackgroundRefresh.schedule()
            await CourseReminderBackgroundRefresh.refresh(container: container)
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 850, height: 620)
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarCompanionView(scheduleViewModel: sharedScheduleViewModel)
                .modelContainer(container)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
