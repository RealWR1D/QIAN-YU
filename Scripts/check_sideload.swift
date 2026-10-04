import Foundation

@main struct SideloadChecks {
    static func main() throws {
        let group = AppInstallationIdentity.originalGroup
        precondition(AppInstallationIdentity.matchingGroup(in: [group]) == group)
        precondition(AppInstallationIdentity.matchingGroup(in: ["group.unrelated", group + ".PERSONAL"]) == group + ".PERSONAL")
        precondition(AppInstallationIdentity.matchingGroup(in: [group + "other"]) == nil)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["Entitlements": ["com.apple.security.application-groups": [group + ".PERSONAL"]]], format: .xml, options: 0)
        let wrapped = Data([0x30, 0x82, 0xff]) + plist + Data([0x00, 0xfe])
        precondition(AppInstallationIdentity.groups(inProfile: wrapped) == [group + ".PERSONAL"])
        precondition(AppInstallationIdentity.groups(inProfile: Data("malformed profile".utf8)).isEmpty)
        let mapped = "com.qianyu.companion.PERSONAL.course-reminder-refresh"
        precondition(AppInstallationIdentity.backgroundRefreshIdentifier(in: ["BGTaskSchedulerPermittedIdentifiers": ["other.task", mapped]]) == mapped)
        precondition(AppInstallationIdentity.backgroundRefreshIdentifier(in: [:]) == "com.qianyu.companion.course-reminder-refresh")
        print("Sideload checks passed: original/personal shared groups, embedded profile parsing and mapped background identifiers")
    }
}
