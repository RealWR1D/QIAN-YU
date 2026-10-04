import Foundation

/// Re-signing may append a personal team's identifier to the shared group.
enum AppInstallationIdentity {
    static let originalGroup = "group.com.qianyu.companion"
    static let sharedGroup: String = {
        let bundle = Bundle.main
        if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let group = matchingGroup(in: groups) { return group }
        if let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url),
           let group = matchingGroup(in: groups(inProfile: data)) { return group }
        return originalGroup
    }()

    static func matchingGroup(in groups: [String]) -> String? {
        groups.first { $0 == originalGroup || $0.hasPrefix(originalGroup + ".") }
    }

    // The OS verifies the provisioning profile during installation. Read its
    // embedded XML only to discover this installed bundle's group identifier.
    static func groups(inProfile data: Data) -> [String] {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    static func backgroundRefreshIdentifier(in info: [String: Any]) -> String {
        let identifiers = info["BGTaskSchedulerPermittedIdentifiers"] as? [String] ?? []
        return identifiers.first { $0.hasSuffix(".course-reminder-refresh") }
            ?? "com.qianyu.companion.course-reminder-refresh"
    }
}
