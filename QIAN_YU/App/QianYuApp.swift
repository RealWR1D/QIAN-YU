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
        WindowGroup {
            MainView(scheduleViewModel: sharedScheduleViewModel)
                .modelContainer(container)
                .onAppear {
                    sharedScheduleViewModel.setContext(container.mainContext)
                    #if os(macOS)
                    let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns")
                    if let path = iconPath, let iconImage = NSImage(contentsOfFile: path) {
                        NSApplication.shared.applicationIconImage = iconImage
                    } else if let iconImage = NSImage(named: "AppIcon") {
                        NSApplication.shared.applicationIconImage = iconImage
                    }
                    #endif
                }
        }
        #if os(macOS)
        .defaultSize(width: 850, height: 620)
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarCompanionView(scheduleViewModel: sharedScheduleViewModel)
                .modelContainer(container)
        } label: {
            Image("QianyuAvatar")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .clipShape(Circle())
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
