import Foundation

enum SyncBackendKind: Equatable {
    case local
    case cloudKit
}

protocol SyncService: AnyObject {
    var kind: SyncBackendKind { get }
    func push(_ snapshot: AppSnapshot) async throws -> AppSnapshot
    func pull(into snapshot: AppSnapshot) async throws -> AppSnapshot
    func bundle(inviteCode: String) async throws -> CircleBundle?
}

enum SyncConfiguration {
    /// Local mode needs no account, no keys, and no paid Apple Developer
    /// membership. Switch this to `.cloudKit` only after the iCloud capability
    /// is on and `AppGroup.cloudKitContainerID` matches your container.
    static let backend: SyncBackendKind = .local

    static func makeService(photos: SnapshotStore) -> any SyncService {
        switch backend {
        case .local:
            return LocalSyncService()
        case .cloudKit:
            return CloudKitSyncService(photos: photos)
        }
    }
}

struct SyncFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }

    static func wrap(_ error: Error) -> SyncFailure {
        if let failure = error as? SyncFailure { return failure }
        if let cloud = error as? CKErrorBox { return SyncFailure(message: cloud.message) }
        return SyncFailure(message: error.localizedDescription)
    }
}

struct CKErrorBox: Error {
    var message: String
}
