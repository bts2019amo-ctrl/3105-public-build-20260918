import Combine
import Foundation

struct PatchStoreAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
    let messageArgument: String?

    init(titleKey: String, messageKey: String, messageArgument: String? = nil) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.messageArgument = messageArgument
    }
}

@MainActor
final class PatchProjectStore: ObservableObject {
    @Published private(set) var items: [PatchLibraryItem] = []
    @Published private(set) var isBusy = false
    @Published var alert: PatchStoreAlert?
    @Published var passwordRequest: PatchPasswordRequest?
    @Published private(set) var unlockErrorKey: String?

    init(autoLoad: Bool = true) {
        if autoLoad { reload() }
    }

    func activate() { reload() }

    func deactivateAndClear() {
        items = []
        passwordRequest = nil
        unlockErrorKey = nil
        alert = nil
    }

    func reload() {
        items = PatchProjectLibrary.load()
    }

    func clearUnlockError() { unlockErrorKey = nil }
    func cancelUnlock() { passwordRequest = nil; unlockErrorKey = nil }

    func requestUnlock(for item: PatchLibraryItem) {
        guard item.isLocked else { return }
        unlockErrorKey = nil
        passwordRequest = PatchPasswordRequest(summary: item.summary, origin: item.origin)
    }

    func unlock(password: String) {
        guard let request = passwordRequest,
              let item = items.first(where: { $0.id == request.id }) else {
            passwordRequest = nil
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try PatchProjectLibrary.readPackage(at: item.packageURL)
            let decoded = try PatchPackageCodec.decode(data, password: password)
            try PatchKeyStore.store(decoded.contentKey, for: item.summary)
            passwordRequest = nil
            unlockErrorKey = nil
            reload()
        } catch {
            unlockErrorKey = (error as? PatchPackageError)?.localizationKey
                ?? "patch.error.password_or_corrupt"
        }
    }

    func create(project: PatchProject, password: String?) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let encoded = try PatchPackageCodec.encodeNew(project: project, password: password)
            let summary = try PatchPackageCodec.inspect(encoded.data)
            let decoded = DecodedPatchPackage(project: project, contentKey: encoded.contentKey)
            try PatchProjectLibrary.installImportedPackage(
                data: encoded.data,
                decoded: decoded,
                summary: summary,
                existingURL: nil
            )
            try PatchProjectLibrary.markAsAuthorCopy(packageID: project.id)
            if summary.isPasswordProtected {
                try PatchKeyStore.store(encoded.contentKey, for: summary)
            }
            reload()
            alert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.created_message")
        } catch {
            present(error)
        }
    }

    func update(project: PatchProject) {
        guard !isBusy,
              let item = items.first(where: { $0.id == project.id }),
              let contentKey = item.contentKey else {
            present(PatchPackageError.privateOperationFailed)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
            let data = try PatchPackageCodec.update(
                original,
                project: project,
                contentKey: contentKey,
                schemaVersion: PatchPackageCodec.latestSchemaVersion
            )
            let decoded = DecodedPatchPackage(project: project, contentKey: contentKey)
            try PatchProjectLibrary.installImportedPackage(
                data: data,
                decoded: decoded,
                summary: try PatchPackageCodec.inspect(data),
                existingURL: item.packageURL,
                origin: item.origin
            )
            reload()
            alert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.updated_message")
        } catch {
            present(error)
        }
    }

    func importPackage(at url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "3105" else {
            present(PatchPackageError.unsupportedFormat)
            return
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            _ = importPackage(data: data, password: nil, origin: nil)
        } catch {
            present(error)
        }
    }

    func importPackage(from source: PatchImportSource) {
        guard case .file(let url) = source else {
            present(PatchPackageError.invalidLocalPackage)
            return
        }
        importPackage(at: url)
    }

    @discardableResult
    func importPackage(data: Data, password: String?, origin: PatchPackageOrigin?) -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            let summary = try PatchPackageCodec.inspect(data)
            let decoded: DecodedPatchPackage?
            if summary.isPasswordProtected && (password ?? "").isEmpty {
                decoded = nil
            } else {
                decoded = try PatchPackageCodec.decode(data, password: password)
            }
            let existingURL = items.first(where: { $0.id == summary.packageID })?.packageURL
            if let decoded {
                try PatchProjectLibrary.installImportedPackage(
                    data: data,
                    decoded: decoded,
                    summary: summary,
                    existingURL: existingURL,
                    origin: origin
                )
                if summary.isPasswordProtected {
                    try PatchKeyStore.store(decoded.contentKey, for: summary)
                }
            } else {
                let name = existingURL?.deletingPathExtension().lastPathComponent ?? "Imported patch"
                _ = try PatchProjectLibrary.save(data: data, projectName: name, existingURL: existingURL)
            }
            reload()
            alert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.imported_message")
            return true
        } catch {
            present(error)
            return false
        }
    }

    func applyInline(_ item: PatchLibraryItem) {
        guard !isBusy else { return }
        guard let project = item.project else { requestUnlock(for: item); return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try DevicePatchService.apply(project: project)
            reload()
            alert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
        } catch {
            present(error)
        }
    }

    func restoreInline(_ item: PatchLibraryItem) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
                throw PatchPackageError.restoreFailed
            }
            try DevicePatchService.restore(receipt: receipt)
            reload()
            alert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
        } catch {
            present(error)
        }
    }

    func presentImportError(_ error: PatchPackageError) { present(error) }

    private func present(_ error: Error) {
        let packageError = error as? PatchPackageError
        alert = PatchStoreAlert(
            titleKey: "common.failed",
            messageKey: packageError?.localizationKey ?? "patch.error.invalid_project",
            messageArgument: packageError?.localizationArgument
        )
    }
}
