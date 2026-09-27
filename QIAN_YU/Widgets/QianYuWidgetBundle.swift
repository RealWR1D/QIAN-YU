//
//  QianYuWidgetBundle.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
@main
struct QianYuWidgetBundle: WidgetBundle {
    var body: some Widget {
        QianYuCourseWidget()
        #if canImport(ActivityKit) && os(iOS)
        QianYuPomodoroLiveActivity()
        #endif
    }
}
#endif
