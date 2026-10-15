import CloudKit
import Foundation

/// Optional sync through CloudKit's public database. Invite codes are record
/// names, so another phone can join without a share sheet. This stays unused
/// until `SyncConfiguration.backend` is `.cloudKit`.
final class CloudKitSyncService: SyncService {
    let kind: SyncBackendKind = .cloudKit
    private let photos: PhotoStoring
    private let container: CKContainer
    private let database: CKDatabase
    private var tempFiles: [URL] = []

    init(photos: PhotoStoring) {
        self.photos = photos
        container = CKContainer(identifier: AppGroup.cloudKitContainerID)
        database = container.publicCloudDatabase
    }

    func push(_ snapshot: AppSnapshot) async throws -> AppSnapshot {
        try await ensureAccount()
        defer { cleanupTemps() }
        var next = snapshot
        var records: [CKRecord] = []
        records.append(contentsOf: try await palRecords(in: &next))
        records.append(contentsOf: try await circleRecords(in: &next))
        records.append(contentsOf: try await habitRecords(in: &next))
        records.append(contentsOf: try await checkInRecords(in: next))
        try await save(records)
        try await deleteRemoved(from: next)
        return next
    }

    func pull(into snapshot: AppSnapshot) async throws -> AppSnapshot {
        try await ensureAccount()
        var next = snapshot
        var habitNames: [String] = []
        var palNames = Set(next.pals.map { CloudNames.pal($0.id) })

        for circle in next.circles {
            guard let record = try await fetchOptional(CloudNames.circle(code: circle.inviteCode)) else { continue }
            absorbDeletedHabits(from: record, into: &next)
            if let remote = parseCircle(record) {
                next.upsertCircle(remote)
                palNames.formUnion(remote.memberships.map { CloudNames.pal($0.palID) })
            }
            habitNames.append(contentsOf: strings(record, "habitIDs"))
        }

        let palIDsToRead = next.pals.filter { $0.isLocalProfile || $0.id == next.activePalID }.map(\.id)
        for palID in palIDsToRead {
            guard let record = try await fetchOptional(CloudNames.pal(palID)) else { continue }
            absorbDeletedHabits(from: record, into: &next)
            if let remote = parsePal(record) {
                next.upsertPal(remote)
            }
            habitNames.append(contentsOf: strings(record, "personalHabitIDs"))
        }

        next.habits.removeAll { next.deletedHabitIDs.contains($0.id) }
        let habitRecords = try await fetch(habitNames)
        var checkInNames: [String] = []
        for record in habitRecords {
            guard let habit = parseHabit(record) else { continue }
            absorbDeletedCheckIns(from: record, habitID: habit.id, into: &next)
            if !next.deletedHabitIDs.contains(habit.id) {
                next.upsertHabit(habit)
                checkInNames.append(contentsOf: strings(record, "checkInIDs"))
            }
        }
        next.checkIns.removeAll { next.isCheckInDeleted($0.id) }

        for record in try await fetch(checkInNames) {
            guard var checkIn = parseCheckIn(record), !next.isCheckInDeleted(checkIn.id) else { continue }
            if record["photo"] is CKAsset {
                checkIn.photoFilename = checkIn.photoFilename ?? "\(checkIn.id.uuidString).jpg"
            }
            next.upsertCheckIn(checkIn)
            if let filename = checkIn.photoFilename,
               let asset = record["photo"] as? CKAsset,
               let url = asset.fileURL,
               let data = try? Data(contentsOf: url) {
                photos.savePhoto(data, filename: filename)
            }
        }

        let missing = palNames.filter { name in
            guard let id = idFrom(name, prefix: "pal-") else { return false }
            return next.pal(id) == nil
        }
        for record in try await fetch(Array(missing)) {
            if let pal = parsePal(record) {
                next.upsertPal(pal)
            }
        }
        return next
    }

    func bundle(inviteCode: String) async throws -> CircleBundle? {
        try await ensureAccount()
        let code = InviteCode.normalize(inviteCode)
        guard let record = try await fetchOptional(CloudNames.circle(code: code)),
              let circle = parseCircle(record) else {
            return nil
        }
        let habitRecords = try await fetch(strings(record, "habitIDs"))
        var habits: [Habit] = []
        var checkInNames: [String] = []
        let removedHabits = Set(uuids(record, "deletedHabitIDs"))
        for habitRecord in habitRecords {
            guard let habit = parseHabit(habitRecord), !removedHabits.contains(habit.id) else { continue }
            habits.append(habit)
            let removedChecks = Set(uuids(habitRecord, "deletedCheckInIDs"))
            checkInNames.append(contentsOf: strings(habitRecord, "checkInIDs").filter { name in
                guard let id = idFrom(name, prefix: "checkin-") else { return false }
                return !removedChecks.contains(id)
            })
        }
        var checkIns: [CheckIn] = []
        for checkRecord in try await fetch(checkInNames) {
            guard var checkIn = parseCheckIn(checkRecord) else { continue }
            if checkRecord["photo"] is CKAsset {
                checkIn.photoFilename = checkIn.photoFilename ?? "\(checkIn.id.uuidString).jpg"
                if let filename = checkIn.photoFilename,
                   let asset = checkRecord["photo"] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    photos.savePhoto(data, filename: filename)
                }
            }
            checkIns.append(checkIn)
        }
        var pals: [Pal] = []
        let palNames = circle.memberships.map { CloudNames.pal($0.palID) }
        for palRecord in try await fetch(palNames) {
            if let pal = parsePal(palRecord) {
                pals.append(pal)
            }
        }
        return CircleBundle(circle: circle, habits: habits, checkIns: checkIns, pals: pals)
    }

    // MARK: - Records

    private func palRecords(in snapshot: inout AppSnapshot) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        for pal in snapshot.pals {
            let record = try await existingOrNew(CloudNames.pal(pal.id), type: "Pal")
            absorbDeletedHabits(from: record, into: &snapshot)
            if let remote = parsePal(record), remote.updatedAt > (snapshot.pal(pal.id)?.updatedAt ?? .distantPast) {
                snapshot.upsertPal(remote)
            }
            guard let current = snapshot.pal(pal.id) else { continue }
            record["displayName"] = current.displayName as NSString
            record["colorHex"] = current.colorHex as NSString
            record["createdAt"] = current.createdAt as NSDate
            record["updatedAt"] = current.updatedAt as NSDate
            let personal = snapshot.habits
                .filter { $0.ownerID == current.id && $0.circleID == nil && !snapshot.deletedHabitIDs.contains($0.id) }
                .map { CloudNames.habit($0.id) }
            let names = union(strings(record, "personalHabitIDs"), personal).filter { name in
                guard let id = idFrom(name, prefix: "habit-") else { return false }
                return !snapshot.deletedHabitIDs.contains(id)
            }
            setStrings(record, "personalHabitIDs", capped(names))
            setStrings(record, "deletedHabitIDs", capped(snapshot.deletedHabitIDs.map(\.uuidString)))
            records.append(record)
        }
        return records
    }

    private func circleRecords(in snapshot: inout AppSnapshot) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        for circle in snapshot.circles {
            let record = try await existingOrNew(CloudNames.circle(code: circle.inviteCode), type: "Circle")
            absorbDeletedHabits(from: record, into: &snapshot)
            if let remote = parseCircle(record) {
                snapshot.upsertCircle(remote)
            }
            guard let merged = snapshot.circles.first(where: { $0.inviteCode == circle.inviteCode }) else { continue }
            record["circleID"] = merged.id.uuidString as NSString
            record["name"] = merged.name as NSString
            record["inviteCode"] = merged.inviteCode as NSString
            record["ownerID"] = merged.ownerID.uuidString as NSString
            record["createdAt"] = merged.createdAt as NSDate
            record["updatedAt"] = merged.updatedAt as NSDate
            setStrings(record, "memberships", merged.memberships.map(MembershipCodec.encode))
            let localHabits = snapshot.habits
                .filter { $0.circleID == merged.id && !snapshot.deletedHabitIDs.contains($0.id) }
                .map { CloudNames.habit($0.id) }
            let names = union(strings(record, "habitIDs"), localHabits).filter { name in
                guard let id = idFrom(name, prefix: "habit-") else { return false }
                return !snapshot.deletedHabitIDs.contains(id)
            }
            setStrings(record, "habitIDs", capped(names))
            setStrings(record, "deletedHabitIDs", capped(snapshot.deletedHabitIDs.map(\.uuidString)))
            records.append(record)
        }
        return records
    }

    private func habitRecords(in snapshot: inout AppSnapshot) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        for habit in snapshot.habits where !snapshot.deletedHabitIDs.contains(habit.id) {
            let record = try await existingOrNew(CloudNames.habit(habit.id), type: "Habit")
            let remoteDeleted = uuids(record, "deletedCheckInIDs")
            for id in remoteDeleted {
                snapshot.noteDeletedCheckIn(id, habitID: habit.id)
            }
            if let remote = parseHabit(record), remote.updatedAt > (snapshot.habit(habit.id)?.updatedAt ?? .distantPast) {
                snapshot.upsertHabit(remote)
            }
            guard let current = snapshot.habit(habit.id) else { continue }
            record["title"] = current.title as NSString
            record["symbolName"] = current.symbolName as NSString
            record["colorHex"] = current.colorHex as NSString
            record["circleID"] = (current.circleID?.uuidString ?? "") as NSString
            record["ownerID"] = current.ownerID.uuidString as NSString
            record["createdAt"] = current.createdAt as NSDate
            record["updatedAt"] = current.updatedAt as NSDate
            record["reminderEnabled"] = (current.reminderEnabled ? 1 : 0) as NSNumber
            record["reminderHour"] = current.reminderHour as NSNumber
            record["reminderMinute"] = current.reminderMinute as NSNumber
            let localChecks = snapshot.checkIns
                .filter { $0.habitID == current.id && !snapshot.isCheckInDeleted($0.id) }
                .map { CloudNames.checkIn($0.id) }
            let names = union(strings(record, "checkInIDs"), localChecks).filter { name in
                guard let id = idFrom(name, prefix: "checkin-") else { return false }
                return !snapshot.isCheckInDeleted(id)
            }
            setStrings(record, "checkInIDs", capped(names, limit: 500))
            let deleted = snapshot.deletedCheckInsByHabit[current.id.uuidString] ?? []
            setStrings(record, "deletedCheckInIDs", capped(union(remoteDeleted.map(\.uuidString), deleted.map(\.uuidString))))
            records.append(record)
        }
        return records
    }

    private func checkInRecords(in snapshot: AppSnapshot) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        for checkIn in snapshot.checkIns where !snapshot.isCheckInDeleted(checkIn.id) && !snapshot.deletedHabitIDs.contains(checkIn.habitID) {
            let record = try await existingOrNew(CloudNames.checkIn(checkIn.id), type: "CheckIn")
            record["habitID"] = checkIn.habitID.uuidString as NSString
            record["palID"] = checkIn.palID.uuidString as NSString
            record["dayKey"] = checkIn.dayKey as NSString
            record["note"] = checkIn.note as NSString
            record["createdAt"] = checkIn.createdAt as NSDate
            if let filename = checkIn.photoFilename {
                record["photoFilename"] = filename as NSString
                if let asset = makeAsset(filename: filename) {
                    record["photo"] = asset
                }
            }
            records.append(record)
        }
        return records
    }

    // MARK: - Parsing

    private func parsePal(_ record: CKRecord) -> Pal? {
        guard let name = record["displayName"] as? String,
              let color = record["colorHex"] as? String,
              let created = record["createdAt"] as? Date,
              let updated = record["updatedAt"] as? Date,
              let id = idFrom(record.recordID.recordName, prefix: "pal-") else {
            return nil
        }
        return Pal(
            id: id,
            displayName: name,
            colorHex: color,
            createdAt: created,
            updatedAt: updated,
            isLocalProfile: false
        )
    }

    private func parseCircle(_ record: CKRecord) -> Circle? {
        guard let idString = record["circleID"] as? String, let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let code = record["inviteCode"] as? String,
              let ownerString = record["ownerID"] as? String, let owner = UUID(uuidString: ownerString),
              let created = record["createdAt"] as? Date,
              let updated = record["updatedAt"] as? Date else {
            return nil
        }
        let memberships = strings(record, "memberships").compactMap(MembershipCodec.decode)
        return Circle(
            id: id,
            name: name,
            inviteCode: code,
            ownerID: owner,
            createdAt: created,
            updatedAt: updated,
            memberships: memberships
        )
    }

    private func parseHabit(_ record: CKRecord) -> Habit? {
        guard let id = idFrom(record.recordID.recordName, prefix: "habit-"),
              let title = record["title"] as? String,
              let symbol = record["symbolName"] as? String,
              let color = record["colorHex"] as? String,
              let ownerString = record["ownerID"] as? String, let owner = UUID(uuidString: ownerString),
              let created = record["createdAt"] as? Date,
              let updated = record["updatedAt"] as? Date else {
            return nil
        }
        let circleRaw = record["circleID"] as? String ?? ""
        return Habit(
            id: id,
            title: title,
            symbolName: symbol,
            colorHex: color,
            circleID: UUID(uuidString: circleRaw),
            ownerID: owner,
            createdAt: created,
            updatedAt: updated,
            reminderEnabled: integer(record, "reminderEnabled") == 1,
            reminderHour: integer(record, "reminderHour") ?? 20,
            reminderMinute: integer(record, "reminderMinute") ?? 0
        )
    }

    private func parseCheckIn(_ record: CKRecord) -> CheckIn? {
        guard let id = idFrom(record.recordID.recordName, prefix: "checkin-"),
              let habitString = record["habitID"] as? String, let habitID = UUID(uuidString: habitString),
              let palString = record["palID"] as? String, let palID = UUID(uuidString: palString),
              let dayKey = record["dayKey"] as? String,
              let created = record["createdAt"] as? Date else {
            return nil
        }
        return CheckIn(
            id: id,
            habitID: habitID,
            palID: palID,
            dayKey: dayKey,
            note: record["note"] as? String ?? "",
            photoFilename: record["photoFilename"] as? String,
            createdAt: created
        )
    }

    // MARK: - CloudKit helpers

    private func ensureAccount() async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available:
            return
        case .noAccount:
            throw SyncFailure(message: "Sign in to iCloud on this iPhone to sync.")
        case .restricted:
            throw SyncFailure(message: "iCloud is restricted on this iPhone.")
        case .couldNotDetermine, .temporarilyUnavailable:
            throw SyncFailure(message: "iCloud couldn't be reached. Try again in a minute.")
        @unknown default:
            throw SyncFailure(message: "iCloud isn't available.")
        }
    }

    private func existingOrNew(_ name: String, type: String) async throws -> CKRecord {
        if let record = try await fetchOptional(name) { return record }
        return CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name))
    }

    private func fetchOptional(_ name: String) async throws -> CKRecord? {
        do {
            return try await database.record(for: CKRecord.ID(recordName: name))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw SyncFailure.wrap(error)
        }
    }

    private func fetch(_ names: [String]) async throws -> [CKRecord] {
        let ids = Array(Set(names.filter { !$0.isEmpty })).map { CKRecord.ID(recordName: $0) }
        guard !ids.isEmpty else { return [] }
        var output: [CKRecord] = []
        var index = 0
        while index < ids.count {
            let end = min(index + 80, ids.count)
            let batch = Array(ids[index..<end])
            let results = try await database.records(for: batch)
            for (_, result) in results {
                switch result {
                case .success(let record):
                    output.append(record)
                case .failure(let error):
                    if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                        continue
                    }
                    throw SyncFailure.wrap(error)
                }
            }
            index = end
        }
        return output
    }

    private func save(_ records: [CKRecord]) async throws {
        let unique = Dictionary(records.map { ($0.recordID.recordName, $0) }, uniquingKeysWith: { _, latest in latest })
        let list = Array(unique.values)
        var index = 0
        while index < list.count {
            let end = min(index + 80, list.count)
            let batch = Array(list[index..<end])
            let result = try await database.modifyRecords(
                saving: batch,
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            )
            for (_, saved) in result.saveResults {
                if case .failure(let error) = saved {
                    throw SyncFailure.wrap(error)
                }
            }
            index = end
        }
    }

    private func deleteRemoved(from snapshot: AppSnapshot) async throws {
        let names = snapshot.deletedHabitIDs.map { CloudNames.habit($0) }
            + snapshot.deletedCheckInsByHabit.values.flatMap { $0 }.map { CloudNames.checkIn($0) }
        let ids = Array(Set(names)).map { CKRecord.ID(recordName: $0) }
        guard !ids.isEmpty else { return }
        var index = 0
        while index < ids.count {
            let end = min(index + 80, ids.count)
            let batch = Array(ids[index..<end])
            _ = try? await database.modifyRecords(saving: [], deleting: batch, savePolicy: .allKeys, atomically: false)
            index = end
        }
    }

    private func absorbDeletedHabits(from record: CKRecord, into snapshot: inout AppSnapshot) {
        for id in uuids(record, "deletedHabitIDs") {
            snapshot.noteDeletedHabit(id)
        }
        snapshot.habits.removeAll { snapshot.deletedHabitIDs.contains($0.id) }
        snapshot.checkIns.removeAll { snapshot.deletedHabitIDs.contains($0.habitID) }
    }

    private func absorbDeletedCheckIns(from record: CKRecord, habitID: UUID, into snapshot: inout AppSnapshot) {
        for id in uuids(record, "deletedCheckInIDs") {
            snapshot.noteDeletedCheckIn(id, habitID: habitID)
        }
        snapshot.checkIns.removeAll { snapshot.isCheckInDeleted($0.id) }
    }

    private func makeAsset(filename: String) -> CKAsset? {
        guard let data = photos.photoData(filename: filename), !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("streak-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            tempFiles.append(url)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    private func cleanupTemps() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }

    private func strings(_ record: CKRecord, _ key: String) -> [String] {
        if let values = record[key] as? [String] { return values }
        if let values = record[key] as? [NSString] { return values.map { $0 as String } }
        return []
    }

    private func setStrings(_ record: CKRecord, _ key: String, _ values: [String]) {
        record[key] = values as NSArray
    }

    private func uuids(_ record: CKRecord, _ key: String) -> [UUID] {
        strings(record, key).compactMap { UUID(uuidString: $0) }
    }

    private func integer(_ record: CKRecord, _ key: String) -> Int? {
        if let value = record[key] as? Int { return value }
        if let value = record[key] as? NSNumber { return value.intValue }
        return nil
    }

    private func idFrom(_ name: String, prefix: String) -> UUID? {
        guard name.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(prefix.count)))
    }

    private func union(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in first + second where seen.insert(value).inserted {
            output.append(value)
        }
        return output
    }

    private func capped(_ values: [String], limit: Int = 300) -> [String] {
        values.count <= limit ? values : Array(values.suffix(limit))
    }
}
