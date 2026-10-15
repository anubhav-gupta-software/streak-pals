import Foundation
import Darwin

enum AppGroup {
    /// Shared by the app and the widget extension. Personal (free) Apple IDs
    /// can't provision this, so the store falls back to the app sandbox.
    static let identifier = "group.app.streakpals.shared"

    /// Placeholder. Match this to the iCloud container once CloudKit is on.
    static let cloudKitContainerID = "iCloud.app.streakpals.ios"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

protocol PhotoStoring: AnyObject {
    func photoData(filename: String) -> Data?
    func savePhoto(_ data: Data, filename: String)
    func deletePhoto(filename: String)
}

final class SnapshotStore: PhotoStoring, @unchecked Sendable {
    let usesAppGroup: Bool
    private let root: URL
    private let memoryOnly: Bool
    private var memorySnapshot: AppSnapshot?
    private var memoryPhotos: [String: Data] = [:]
    private let snapshotURL: URL
    private let payloadURL: URL
    private let photosURL: URL
    private let lockURL: URL

    init(memory snapshot: AppSnapshot? = nil) {
        if let snapshot {
            memoryOnly = true
            usesAppGroup = false
            root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            memorySnapshot = snapshot
        } else if let container = AppGroup.containerURL {
            memoryOnly = false
            usesAppGroup = true
            root = container
        } else {
            memoryOnly = false
            usesAppGroup = false
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            root = base.appendingPathComponent("StreakPals", isDirectory: true)
        }
        snapshotURL = root.appendingPathComponent("snapshot.json")
        payloadURL = root.appendingPathComponent("widget-payload.json")
        photosURL = root.appendingPathComponent("Photos", isDirectory: true)
        lockURL = root.appendingPathComponent("snapshot.lock")
    }

    func load() -> AppSnapshot {
        if memoryOnly { return memorySnapshot ?? .empty }
        return (try? withLock { try readSnapshot() }) ?? .empty
    }

    func save(_ snapshot: AppSnapshot) {
        if memoryOnly {
            memorySnapshot = snapshot
            return
        }
        try? withLock {
            try writeSnapshot(snapshot)
        }
    }

    @discardableResult
    func checkInActivePal(
        habitID: UUID,
        note: String = "",
        photoJPEG: Data? = nil,
        now: Date = .now
    ) throws -> CheckInWrite {
        if memoryOnly {
            var snapshot = memorySnapshot ?? .empty
            let write = try Journal.checkIn(
                snapshot: &snapshot,
                habitID: habitID,
                note: note,
                attachPhoto: photoJPEG != nil,
                now: now
            )
            if let data = photoJPEG, let filename = write.photoFilename {
                memoryPhotos[filename] = data
            }
            memorySnapshot = snapshot
            return write
        }
        return try withLock {
            var snapshot = try readSnapshot()
            let write = try Journal.checkIn(
                snapshot: &snapshot,
                habitID: habitID,
                note: note,
                attachPhoto: photoJPEG != nil,
                now: now
            )
            if let data = photoJPEG, let filename = write.photoFilename {
                try writePhoto(data, filename: filename)
            }
            try writeSnapshot(snapshot)
            return write
        }
    }

    func photoData(filename: String) -> Data? {
        let safe = (filename as NSString).lastPathComponent
        guard safe == filename, !safe.isEmpty else { return nil }
        if memoryOnly { return memoryPhotos[safe] }
        return try? Data(contentsOf: photosURL.appendingPathComponent(safe))
    }

    func savePhoto(_ data: Data, filename: String) {
        let safe = (filename as NSString).lastPathComponent
        guard safe == filename, !safe.isEmpty else { return }
        if memoryOnly {
            memoryPhotos[safe] = data
            return
        }
        try? writePhoto(data, filename: safe)
    }

    func deletePhoto(filename: String) {
        let safe = (filename as NSString).lastPathComponent
        guard safe == filename, !safe.isEmpty else { return }
        if memoryOnly {
            memoryPhotos[safe] = nil
            return
        }
        try? FileManager.default.removeItem(at: photosURL.appendingPathComponent(safe))
    }

    private func readSnapshot() throws -> AppSnapshot {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return .empty }
        let data = try Data(contentsOf: snapshotURL)
        return try JSONDecoder.snapshot.decode(AppSnapshot.self, from: data)
    }

    private func writeSnapshot(_ snapshot: AppSnapshot) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder.snapshot.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
        guard usesAppGroup else { return }
        let payload = WidgetPayload.build(from: snapshot)
        let payloadData = try JSONEncoder.snapshot.encode(payload)
        try payloadData.write(to: payloadURL, options: .atomic)
    }

    private func writePhoto(_ data: Data, filename: String) throws {
        try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        try data.write(to: photosURL.appendingPathComponent(filename), options: .atomic)
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return try body() }
        defer { close(fd) }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
}

extension JSONEncoder {
    static var snapshot: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var snapshot: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
