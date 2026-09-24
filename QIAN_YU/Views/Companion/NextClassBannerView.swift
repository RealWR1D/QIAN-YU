//
//  NextClassBannerView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct NextClassBannerView: View {
    public let nextCourse: CourseItem?
    public var onAskQianyu: () -> Void

    public init(nextCourse: CourseItem?, onAskQianyu: @escaping () -> Void) {
        self.nextCourse = nextCourse
        self.onAskQianyu = onAskQianyu
    }

    public var body: some View {
        Group {
            if let course = nextCourse {
                HStack(spacing: 12) {
                    // 左侧图标
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 20))
                        .foregroundColor(course.swiftUIColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("下一节课 · \(course.name)")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)

                            if let minutes = course.minutesUntilClassToday() {
                                if minutes == 0 {
                                    Text("正在上课")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.18))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                } else {
                                    Text("\(minutes)分钟后")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.18))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Label(course.formattedTime, systemImage: "timer")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            if !course.classroom.isEmpty {
                                Label(course.classroom, systemImage: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // 询问千语按钮
                    Button {
                        onAskQianyu()
                    } label: {
                        HStack(spacing: 2) {
                            Text("千语叮嘱")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
        }
    }
}
