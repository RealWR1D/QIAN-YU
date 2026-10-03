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

    @MainActor static let sharedContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            CourseItem.self
        ])

        #if os(macOS) && QIANYU_LOCAL_DISTRIBUTION
        // Ad hoc signatures cannot access the developer team's App Group.
        // Use a stable, separate store; never move or delete the signed build's data.
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("QIAN YU/LocalDistribution", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                schema: schema, url: directory.appendingPathComponent("default.store"),
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法初始化本地分发数据库: \(error)")
        }
        #else
        // Try CloudKit first, then the signed build's local storage.
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)]
        ) {
            return cloudContainer
        } else {
            do {
                let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("无法初始化 SwiftData ModelContainer: \(error)")
            }
        }
        #endif

    }()

    init() {
        self.container = Self.sharedContainer

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
                    #if DEBUG && os(iOS)
                    if ProcessInfo.processInfo.arguments.contains("--qianyu-test-pomodoro") {
                        sharedPomodoroViewModel.reset()
                        sharedPomodoroViewModel.start()
                    }
                    #endif
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
                    if sharedScheduleViewModel.handleExternalCalendarURL(url) {
                        return
                    }
                    NSLog("📢 [QianYuApp] Received openURL: %@", url.absoluteString)
                    if url.scheme == "qianyu" {
                        let host = url.host ?? ""
                        if host == "startPomodoro" || host == "testLiveActivity" || url.path.contains("startPomodoro") {
                            #if os(iOS)
                            let res = LiveActivityManager.shared.startPomodoro(
                                sessionTitle: "专注中",
                                totalSeconds: 25 * 60,
                                remainingSeconds: 25 * 60,
                                endDate: Date().addingTimeInterval(TimeInterval(25 * 60)),
                                quote: "「当破即破，当当当！」"
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

//
// Special Thanks:
//      icon : Bilibili@唐可可为什么是神
//
// Inspired by:
//      一条啥龙、Bilibili@小陈的脚凑凑的
//
// Bulit by:
//      RealWRLD @ cloud.lorra
//
