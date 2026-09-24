//
//  AddCourseSheet.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var classroom: String = ""
    @State private var teacher: String = ""
    @State private var weekday: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var remindBeforeMinutes: Int = 15
    @State private var selectedColorHex: String = "#FF9500"
    @State private var weekMode: CourseWeekMode = .all
    @State private var startWeek: Int = 1
    @State private var endWeek: Int = 16

    public var onSave: (CourseItem) -> Void

    private let weekdays = [
        (1, "周一"), (2, "周二"), (3, "周三"), (4, "周四"),
        (5, "周五"), (6, "周六"), (7, "周日")
    ]

    private let reminderOptions = [5, 10, 15, 20, 30, 45, 60]

    private let presetColors = [
        "#FF9500", // 橙 (千语主色)
        "#34C759", // 绿
        "#007AFF", // 蓝
        "#AF52DE", // 紫
        "#FF2D55", // 粉红
        "#FFCC00"  // 黄
    ]

    public init(initialWeekday: Int = 1, onSave: @escaping (CourseItem) -> Void) {
        self._weekday = State(initialValue: initialWeekday)
        self.onSave = onSave

        // 默认上课时间 08:30 - 10:05
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: Date())
        comp.hour = 8
        comp.minute = 30
        let start = cal.date(from: comp) ?? Date()

        comp.hour = 10
        comp.minute = 5
        let end = cal.date(from: comp) ?? Date()

        self._startTime = State(initialValue: start)
        self._endTime = State(initialValue: end)
    }

    private var isTimeValid: Bool {
        let cal = Calendar.current
        let sHour = cal.component(.hour, from: startTime)
        let sMin = cal.component(.minute, from: startTime)
        let eHour = cal.component(.hour, from: endTime)
        let eMin = cal.component(.minute, from: endTime)
        return (eHour * 60 + eMin) > (sHour * 60 + sMin)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("课程名称 (必填，例如：高等数学)", text: $name)
                    TextField("教室 / 地点 (例如：正心楼 312)", text: $classroom)
                    TextField("任课教师 (可选)", text: $teacher)
                }

                Section(header: Text("时间与周期")) {
                    Picker("上课星期", selection: $weekday) {
                        ForEach(weekdays, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }

                    DatePicker("上课时间", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("下课时间", selection: $endTime, displayedComponents: .hourAndMinute)

                    if !isTimeValid {
                        Text("⚠️ 下课时间必须晚于上课时间")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("周数与单双周规则")) {
                    Picker("周数模式", selection: $weekMode) {
                        ForEach(CourseWeekMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Stepper("起始周数: 第 \(startWeek) 周", value: $startWeek, in: 1...endWeek)
                    Stepper("结束周数: 第 \(endWeek) 周", value: $endWeek, in: startWeek...30)
                }

                Section(header: Text("千语提醒偏好")) {
                    Picker("提前提醒时间", selection: $remindBeforeMinutes) {
                        ForEach(reminderOptions, id: \.self) { mins in
                            Text("提前 \(mins) 分钟").tag(mins)
                        }
                    }

                    HStack {
                        Text("课表标签色")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(presetColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorHex = hex
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加新课程")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCourse()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid)
                }
            }
        }
    }

    private func saveCourse() {
        let cal = Calendar.current
        let sHour = cal.component(.hour, from: startTime)
        let sMin = cal.component(.minute, from: startTime)
        let eHour = cal.component(.hour, from: endTime)
        let eMin = cal.component(.minute, from: endTime)

        let newCourse = CourseItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            classroom: classroom.trimmingCharacters(in: .whitespacesAndNewlines),
            teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
            weekday: weekday,
            startHour: sHour,
            startMinute: sMin,
            endHour: eHour,
            endMinute: eMin,
            remindBeforeMinutes: remindBeforeMinutes,
            isEnabled: true,
            colorHex: selectedColorHex,
            weekModeRaw: weekMode.rawValue,
            startWeek: startWeek,
            endWeek: endWeek
        )

        onSave(newCourse)
        dismiss()
    }
}
