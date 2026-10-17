import Combine
import Foundation

struct PatchDraftRequest: Identifiable {
    let id = UUID()
    let draft: PatchProjectDraft
}

enum PatchImportSource: Equatable {
    case file(URL)
    case invalid
}

enum PatchImportRoute {
    static func resolve(_ incomingURL: URL) -> PatchImportSource {
        if incomingURL.isFileURL {
            return incomingURL.pathExtension.lowercased() == "3105"
                ? .file(incomingURL)
                : .invalid
        }
        return .invalid
    }
}

struct PatchImportRequest: Identifiable, Equatable {
    let id = UUID()
    let source: PatchImportSource
}

@MainActor
final class PatchDraftCoordinator: ObservableObject {
    @Published var request: PatchDraftRequest?
    @Published var importRequest: PatchImportRequest?

    func present(_ draft: PatchProjectDraft) {
        request = PatchDraftRequest(draft: draft)
    }

    func clear() {
        request = nil
    }

    func presentImport(_ url: URL) {
        importRequest = PatchImportRequest(source: PatchImportRoute.resolve(url))
    }

    func clearImport() {
        importRequest = nil
    }
}
