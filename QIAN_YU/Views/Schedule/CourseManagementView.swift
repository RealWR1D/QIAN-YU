import SwiftUI

/// A semester-wide catalog, independent of the timetable's day/week filters.
struct CourseManagementView: View {
    @Bindable var viewModel: CourseScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var editingCourse: CourseItem?
    @State private var isAddingCourse = false
    @State private var pendingDeletion: CourseDeletion?
    @State private var errorMessage: String?

    private struct CourseGroup: Identifiable {
        let id: String
        let courses: [CourseItem]
        var name: String { courses.first?.name ?? "" }
    }

    private struct CourseDeletion: Identifiable {
        let id = UUID()
        let courses: [CourseItem]
        let message: String
    }

    private var allGroups: [CourseGroup] {
        let grouped = Dictionary(grouping: viewModel.courses) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        }
        return grouped.map { key, courses in
            CourseGroup(id: key, courses: courses.sorted {
                if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
                if $0.startTotalMinutes != $1.startTotalMinutes { return $0.startTotalMinutes < $1.startTotalMinutes }
                if $0.startWeek != $1.startWeek { return $0.startWeek < $1.startWeek }
                return $0.id.uuidString < $1.id.uuidString
            })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var visibleGroups: [CourseGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allGroups.filter { group in
            query.isEmpty || group.courses.contains {
                [$0.name, $0.teacher, $0.classroom].contains { $0.localizedStandardContains(query) }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("共 \(allGroups.count) 门课程 · \(viewModel.courses.count) 条上课安排")
                        .font(.headline)
                    Text("同名课程集中展示，包含全学期所有周次。可编辑单条安排，或一次删除整门课程。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("搜索课程、教师或地点", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 6)
                }
                .padding()
                Divider()
                if visibleGroups.isEmpty {
                    ContentUnavailableView {
                        Label(viewModel.courses.isEmpty ? "还没有课程" : "没有找到课程", systemImage: "books.vertical")
                    } description: {
                        Text(viewModel.courses.isEmpty ? "添加课程，开始管理本学期的上课安排。" : "试试其他课程名称、教师或地点。")
                    } actions: {
                        if viewModel.courses.isEmpty {
                            Button("添加课程") { isAddingCourse = true }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(visibleGroups) { group in
                                groupCard(group)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("课程管理")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddingCourse = true } label: {
                        Label("添加课程", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingCourse) {
                AddCourseSheet { viewModel.addCourse($0) }
            }
            .sheet(item: $editingCourse) { course in
                AddCourseSheet(course: course) { draft in
                    viewModel.updateCourse(course, from: draft)
                }
            }
            .alert("确认删除？", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { deletion in
                Button("取消", role: .cancel) { pendingDeletion = nil }
                Button("删除", role: .destructive) {
                    errorMessage = viewModel.deleteCourses(deletion.courses)
                    pendingDeletion = nil
                }
            } message: { deletion in
                Text(deletion.message)
            }
            .alert("课程保存失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好的", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 740, minHeight: 560, idealHeight: 720)
        #endif
    }

    private func groupCard(_ group: CourseGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Label(group.name, systemImage: "book.closed.fill")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    pendingDeletion = CourseDeletion(courses: group.courses, message: String(localized: "将删除「\(group.name)」的全部 \(group.courses.count) 条上课安排及所有周次，无法撤销。"))
                } label: {
                    Label("删除整门课", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            ForEach(group.courses) { course in
                Divider()
                arrangementRow(course)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func arrangementRow(_ course: CourseItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(course.swiftUIColor).frame(width: 8, height: 8)
                Text("\(course.weekdayName) · \(course.formattedTime)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !course.isEnabled {
                    Text("提醒已关闭").font(.caption).foregroundStyle(.secondary)
                }
            }
            Label(course.weekModeDisplay, systemImage: "calendar")
            Label(course.classroom.isEmpty ? String(localized: "地点未填写") : course.classroom, systemImage: "mappin.and.ellipse")
            Label(course.teacher.isEmpty ? String(localized: "教师未填写") : course.teacher, systemImage: "person")
            HStack {
                Label("提前 \(course.remindBeforeMinutes) 分钟提醒", systemImage: "bell")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("编辑") { editingCourse = course }
                Button("删除此安排", role: .destructive) {
                    pendingDeletion = CourseDeletion(courses: [course], message: String(localized: "将删除「\(course.name)」在\(course.weekdayName) \(course.formattedTime) 的安排（\(course.weekModeDisplay)）。其他安排不受影响。"))
                }
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
