import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSettingsView: View {
    @Environment(\.modelContext) private var context
    let settings: AppSettings
    let schedule: CourseScheduleViewModel
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var result: String?
    var body: some View {
        Form {
            Section("数据备份") {
                Text("备份课表、聊天、人设、称呼和学期起始日。备份不包含 API Key。文件中包含你的聊天内容，请自行妥善保存。")
                Button("导出备份") {
                    do { document = BackupDocument(data:try AppBackup.export(context:context, settings:settings)); exporting = true }
                    catch { result = error.localizedDescription }
                }
                Button("恢复备份") { importing = true }
                Text("恢复时合并缺少的课程和消息，保留现有记录；人设、称呼和学期起始日使用备份中的值。")
            }
            if let result { Text(result).textSelection(.enabled) }
        }
        .navigationTitle("备份与恢复")
        .fileExporter(isPresented:$exporting, document:document, contentType:.json, defaultFilename:"QIAN-YU-backup") { completion in
            switch completion { case .success: result = "备份已导出"; case .failure(let error): result = error.localizedDescription }
        }
        .fileImporter(isPresented:$importing, allowedContentTypes:[.json]) { completion in
            do {
                let url = try completion.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 50_000_000 else { throw CocoaError(.fileReadTooLarge) }
                try AppBackup.restore(Data(contentsOf:url), context:context, settings:settings)
                schedule.loadCourses()
                NotificationCenter.default.post(name:Notification.Name("qianyuBackupRestored"), object:nil)
                result = "备份已恢复"
            } catch { result = error.localizedDescription }
        }
    }
}
