//
//  AddCourseSheet.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled = true
    private let isEditing: Bool
    private let maximumWeek: Int

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
    @State private var usesSpecificWeeks: Bool = false
    @State private var specificWeeksText: String = ""
    @State private var saveErrorMessage: String? = nil
    @State private var isShowingSaveError: Bool = false

    public var onSave: (CourseItem) -> String?

    private let weekdays = [
        (1, String(localized: "周一")), (2, String(localized: "周二")),
        (3, String(localized: "周三")), (4, String(localized: "周四")),
        (5, String(localized: "周五")), (6, String(localized: "周六")),
        (7, String(localized: "周日"))
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

    public init(initialWeekday: Int = 1, course: CourseItem? = nil, onSave: @escaping (CourseItem) -> String?) {
        self.isEditing = course != nil
        self.maximumWeek = max(30, max(course?.endWeek ?? 0, course?.activeWeeks.max() ?? 0))
        self._weekday = State(initialValue: course?.weekday ?? initialWeekday)
        if let course {
            _name = State(initialValue: course.name)
            _classroom = State(initialValue: course.classroom)
            _teacher = State(initialValue: course.teacher)
            _isEnabled = State(initialValue: course.isEnabled)
            _remindBeforeMinutes = State(initialValue: course.remindBeforeMinutes)
            _selectedColorHex = State(initialValue: course.colorHex)
            _weekMode = State(initialValue: course.weekMode)
            _startWeek = State(initialValue: course.startWeek)
            _endWeek = State(initialValue: course.endWeek)
            _usesSpecificWeeks = State(initialValue: !course.activeWeeks.isEmpty)
            _specificWeeksText = State(initialValue: course.activeWeeks.sorted().map(String.init).joined(separator: ", "))
        }
        self.onSave = onSave

        // 默认上课时间 08:30 - 10:05
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: Date())
        comp.hour = course?.startHour ?? 8
        comp.minute = course?.startMinute ?? 30
        let start = cal.date(from: comp) ?? Date()

        comp.hour = course?.endHour ?? 10
        comp.minute = course?.endMinute ?? 5
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

    private var selectedSpecificWeeks: [Int]? {
        guard usesSpecificWeeks else { return nil }
        let normalized = specificWeeksText
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
        let tokens = normalized.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty,
              tokens.allSatisfy({ Int($0).map { (1...maximumWeek).contains($0) } ?? false }) else {
            return nil
        }
        return Array(Set(tokens.compactMap(Int.init))).sorted()
    }

    private var isWeekSelectionValid: Bool {
        usesSpecificWeeks ? selectedSpecificWeeks != nil : !defaultSpecificWeekText().isEmpty
    }

    private func defaultSpecificWeekText() -> String {
        (startWeek...endWeek)
            .filter { week in
                switch weekMode {
                case .all: return true
                case .oddOnly: return week % 2 == 1
                case .evenOnly: return week % 2 == 0
                }
            }
            .map(String.init)
            .joined(separator: ", ")
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
                    Toggle("指定具体周次", isOn: $usesSpecificWeeks)

                    if usesSpecificWeeks {
                        TextField("例如：1, 2, 4, 7", text: $specificWeeksText)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif
                        Text("输入 1–\(maximumWeek) 的周数，用逗号分隔；可用于间断周或单次课程。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        if selectedSpecificWeeks == nil {
                            Text("请输入至少一个 1–\(maximumWeek) 之间的周数。")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    } else {
                        Picker("周数模式", selection: $weekMode) {
                            ForEach(CourseWeekMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }

                        Stepper("起始周数: 第 \(startWeek) 周", value: $startWeek, in: 1...endWeek)
                        Stepper("结束周数: 第 \(endWeek) 周", value: $endWeek, in: startWeek...maximumWeek)
                    }
                }

                Section(header: Text("千语提醒偏好")) {
                    Toggle("启用课程提醒", isOn: $isEnabled)
                    Picker("提前提醒时间", selection: $remindBeforeMinutes) {
                        ForEach(Array(Set(reminderOptions + [remindBeforeMinutes])).sorted(), id: \.self) { mins in
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
            .navigationTitle(isEditing ? String(localized: "编辑上课安排") : String(localized: "添加新课程"))
            #if os(macOS)
            .formStyle(.grouped)
            .frame(minWidth: 520, minHeight: 620)
            #endif
            .onChange(of: usesSpecificWeeks) { _, isEnabled in
                if isEnabled && specificWeeksText.isEmpty {
                    specificWeeksText = defaultSpecificWeekText()
                }
            }
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid || !isWeekSelectionValid)
                }
            }
            .alert("保存课程失败", isPresented: $isShowingSaveError) {
                Button("继续编辑", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? String(localized: "请稍后重试。"))
            }
        }
    }

    private func saveCourse() {
        let cal = Calendar.current
        let sHour = cal.component(.hour, from: startTime)
        let sMin = cal.component(.minute, from: startTime)
        let eHour = cal.component(.hour, from: endTime)
        let eMin = cal.component(.minute, from: endTime)

        let specificWeeks = selectedSpecificWeeks ?? []
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
            isEnabled: isEnabled,
            colorHex: selectedColorHex,
            weekModeRaw: usesSpecificWeeks ? CourseWeekMode.all.rawValue : weekMode.rawValue,
            startWeek: specificWeeks.first ?? startWeek,
            endWeek: specificWeeks.last ?? endWeek,
            activeWeeksRaw: usesSpecificWeeks ? specificWeeks.map(String.init).joined(separator: ",") : ""
        )

        if let errorMessage = onSave(newCourse) {
            saveErrorMessage = errorMessage
            isShowingSaveError = true
        } else {
            dismiss()
        }
    }
}
