import Foundation

final class LocalSyncService: SyncService {
    let kind: SyncBackendKind = .local

    func push(_ snapshot: AppSnapshot) async throws -> AppSnapshot { snapshot }

    func pull(into snapshot: AppSnapshot) async throws -> AppSnapshot { snapshot }

    func bundle(inviteCode: String) async throws -> CircleBundle? { nil }
}
