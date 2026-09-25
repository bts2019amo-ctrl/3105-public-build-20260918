import Foundation
import UIKit

// Normal iOS sandbox implementation. The app can browse only its own container.
struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let containerPath: String
    let version: String
    let icon: UIImage?

    var id: String { bundleID }
    var displayName: String {
        AppDisplayNamePolicy.resolve(bundleID: bundleID, candidates: [name])
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FileEntry: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?
    let childCount: Int?

    var id: String { path }
    var sizeText: String {
        guard size >= 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    init(name: String, path: String, isDirectory: Bool, size: Int64, modifiedAt: Date? = nil, childCount: Int? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
        self.childCount = childCount
    }

    func withDirectorySummary(_ summary: FileBrowserDirectorySummary?) -> FileEntry {
        FileEntry(name: name, path: path, isDirectory: isDirectory, size: summary?.byteCount ?? -2, modifiedAt: modifiedAt, childCount: summary?.childCount)
    }
}

enum ContainerStore {
    static let appDataRoot = NSHomeDirectory()
    static let systemDataRoot = NSHomeDirectory()
    static let researchAppIdentifiers: [String] = []

    private static var ownBundleID: String { Bundle.main.bundleIdentifier ?? "com.external.system" }
    private static var ownName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "EXTERNAL SYSTEM" }
    private static var ownVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    static func resolveAppContainerPath(bundleID: String) -> String? {
        guard bundleID == ownBundleID else { return nil }
        return NSHomeDirectory()
    }

    static func resolveAppContainerPathByMetadataScan(bundleID: String) -> String? {
        resolveAppContainerPath(bundleID: bundleID)
    }

    static func installedAppsFromAPI() -> [InstalledApp] {
        [InstalledApp(bundleID: ownBundleID, name: ownName, containerPath: NSHomeDirectory(), version: ownVersion, icon: nil)]
    }

    static func applicationBundleMetadataCatalog() -> [String: ApplicationBundleMetadata] { [:] }

    static func applyingBundleMetadata(
        to apps: [InstalledApp],
        catalog: [String: ApplicationBundleMetadata]
    ) -> [InstalledApp] {
        apps.map { app in
            guard let metadata = catalog[app.bundleID] else { return app }
            return InstalledApp(bundleID: app.bundleID, name: metadata.displayName, containerPath: app.containerPath, version: metadata.version, icon: app.icon)
        }
    }

    static func dynamicAppIdentifiers() -> [String] { [ownBundleID] }

    static func installedAppsFromMCM(
        identifiers: [String]? = nil,
        bundleMetadata: [String: ApplicationBundleMetadata] = [:]
    ) -> [InstalledApp] { [] }

    static func installedAppsFromMHACandidates(
        identifiers: [String],
        bundleMetadata: [String: ApplicationBundleMetadata],
        progress: (([InstalledApp]) -> Void)? = nil
    ) -> [InstalledApp] {
        progress?([])
        return []
    }

    static func launchServicesStoreIdentifiers() -> [String] { [] }

    static func isApplicationContainerPath(_ path: String) -> Bool {
        let root = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.path
        return candidate == root || candidate.hasPrefix(root + "/")
    }

    static func enumerateDirectories(path: String, maxInode: Int64 = 2_000_000) -> [String] {
        guard isApplicationContainerPath(path) else { return [] }
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(atPath: path))?.map { (path as NSString).appendingPathComponent($0) } ?? []
    }

    static func enumerateDirectoriesWithTraversalGrant(path: String) -> [String] {
        enumerateDirectories(path: path)
    }

    static func readContainerMetadata(containerPath: String) -> ContainerMetadata? { nil }

    static func metadataPath(for containerPath: String) -> String {
        (containerPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
    }

    static func grantContainerAccess(_ containerPath: String) -> Int64 { -1 }

    static func containersFromFilesystem() -> [InstalledApp] { [] }

    static func inferredApp(
        for fallback: InstalledApp,
        knownAppsByBundleID: [String: InstalledApp],
        launchServicesIdentifiers: Set<String>
    ) -> InstalledApp? { fallback.bundleID == ownBundleID ? fallback : nil }

    static func inferUnidentifiedApps(
        in apps: [InstalledApp],
        knownApps: [InstalledApp],
        launchServicesIdentifiers: Set<String> = []
    ) -> [InstalledApp] { apps }

    static func listFiles(at path: String) -> [FileEntry] {
        guard isApplicationContainerPath(path) else { return [] }
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return names.compactMap { name in
            guard !name.hasPrefix(".") else { return nil }
            let full = (path as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDirectory) else { return nil }
            let attributes = try? fm.attributesOfItem(atPath: full)
            let size = isDirectory.boolValue ? -1 : (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            return FileEntry(name: name, path: full, isDirectory: isDirectory.boolValue, size: size, modifiedAt: attributes?[.modificationDate] as? Date)
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func readTextFile(at path: String, limit: Int = 200_000) -> String {
        guard isApplicationContainerPath(path), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return "Unable to read file."
        }
        let truncated = data.prefix(limit)
        if let text = String(data: truncated, encoding: .utf8) { return data.count > limit ? text + "\n… [truncated]" : text }
        if let text = String(data: truncated, encoding: .utf16) { return data.count > limit ? text + "\n… [truncated]" : text }
        return "Binary data (\(data.count) bytes) — not text."
    }
}
