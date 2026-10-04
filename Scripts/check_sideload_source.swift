import Foundation

// Check the actual generated source with Apple's decoder, including ISO-8601
// dates (fractional seconds are rejected by its default .iso8601 strategy).
struct SideloadSource: Decodable {
    struct App: Decodable {
        struct Version: Decodable {
            let version, buildVersion: String
            let date: Date
            let downloadURL: URL
            let size: Int
            let sha256: String
        }
        struct Permissions: Decodable {
            let entitlements: [String]
            let privacy: [String: String]
        }
        let name, bundleIdentifier: String
        let iconURL: URL
        let versions: [Version]
        let appPermissions: Permissions
    }
    let name, identifier: String
    let sourceURL: URL
    let apps: [App]
}
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let source = try decoder.decode(SideloadSource.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
guard source.apps.count == 1, let app = source.apps.first,
      app.bundleIdentifier == "com.qianyu.companion",
      let version = app.versions.first, version.size > 0,
      version.sha256.count == 64,
      version.downloadURL.scheme == "https", source.sourceURL.scheme == "https" else {
    fatalError("Invalid generated SideStore source")
}
print("SideStore source decoded: \(app.name) \(version.version) (\(version.buildVersion))")
