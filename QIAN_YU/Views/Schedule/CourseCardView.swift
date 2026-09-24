//
//  CourseCardView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct CourseCardView: View {
    public let course: CourseItem
    public var onToggle: () -> Void
    public var onDelete: () -> Void

    public init(course: CourseItem, onToggle: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.course = course
        self.onToggle = onToggle
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 颜色标识条
            RoundedRectangle(cornerRadius: 3)
                .fill(course.swiftUIColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(course.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(course.isEnabled ? .primary : .secondary)

                    Spacer()

                    // 提醒开关
                    Toggle("", isOn: Binding(
                        get: { course.isEnabled },
                        set: { _ in onToggle() }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.85)
                }

                HStack(spacing: 12) {
                    Label(course.formattedTime, systemImage: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if !course.classroom.isEmpty {
                        Label(course.classroom, systemImage: "location")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    if !course.teacher.isEmpty {
                        Label(course.teacher, systemImage: "person")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(course.weekModeDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())

                    Text("提前 \(course.remindBeforeMinutes) 分钟千语推送")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(course.swiftUIColor.opacity(0.12))
                        .foregroundColor(course.swiftUIColor)
                        .clipShape(Capsule())

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
