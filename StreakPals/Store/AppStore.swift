import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AppStore {
    private(set) var snapshot: AppSnapshot
    private let persistence: SnapshotStore
    private let sync: any SyncService
    private let schedulesReminders: Bool

    var showSettings = false
    var pendingCheckIn: HabitIDBox?
    var celebrationText: String?
    var celebrationID = UUID()
    var syncing = false
    var lastSyncError: String?
    var lastSyncedAt: Date?
    private var syncQueued = false
    private var revision = 0

    var usesAppGroup: Bool { persistence.usesAppGroup }
    var backend: SyncBackendKind { sync.kind }

    init(
        persistence: SnapshotStore = SnapshotStore(),
        sync: (any SyncService)? = nil,
        schedulesReminders: Bool = true
    ) {
        self.persistence = persistence
        self.schedulesReminders = schedulesReminders
        self.sync = sync ?? SyncConfiguration.makeService(photos: persistence)
        snapshot = persistence.load()
        if schedulesReminders {
            ReminderScheduler.reschedule(snapshot: snapshot)
        }
    }

    func reloadFromDisk() {
        let fresh = persistence.load()
        guard fresh != snapshot else { return }
        snapshot = fresh
        reschedule()
    }

    func open(_ url: URL) {
        guard url.scheme == "streakpals" else { return }
        let host = url.host?.lowercased()
        guard host == "checkin" || host == "habit" else { return }
        let token = url.pathComponents.last(where: { $0 != "/" }) ?? ""
        guard let id = UUID(uuidString: token) else { return }
        pendingCheckIn = HabitIDBox(id: id)
    }

    func createProfile(name: String) throws {
        let trimmed = clean(name, limit: 24)
        guard !trimmed.isEmpty else { throw AppError.emptyName }
        let pal = Pal(
            id: UUID(),
            displayName: trimmed,
            colorHex: Palette.palColors[0],
            createdAt: .now,
            updatedAt: .now,
            isLocalProfile: true
        )
        snapshot.pals.append(pal)
        snapshot.activePalID = pal.id
        commit()
    }

    func renameActivePal(_ name: String) {
        guard let id = snapshot.activePalID,
              let index = snapshot.pals.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = clean(name, limit: 24)
        guard !trimmed.isEmpty else { return }
        snapshot.pals[index].displayName = trimmed
        snapshot.pals[index].updatedAt = .now
        commit()
    }

    @discardableResult
    func addLocalPal(name: String) throws -> Pal {
        let trimmed = clean(name, limit: 24)
        guard !trimmed.isEmpty else { throw AppError.emptyName }
        let localCount = snapshot.pals.filter(\.isLocalProfile).count
        let pal = Pal(
            id: UUID(),
            displayName: trimmed,
            colorHex: Palette.palColors[localCount % Palette.palColors.count],
            createdAt: .now,
            updatedAt: .now,
            isLocalProfile: true
        )
        snapshot.pals.append(pal)
        commit()
        return pal
    }

    func switchToPal(_ id: UUID) {
        guard snapshot.pals.contains(where: { $0.id == id && $0.isLocalProfile }) else { return }
        snapshot.activePalID = id
        commit()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        snapshot.remindersEnabled = enabled
        commit()
    }

    @discardableResult
    func createCircle(name: String) throws -> Circle {
        guard let pal = snapshot.activePal else { throw AppError.needProfile }
        let trimmed = clean(name, limit: 32)
        guard !trimmed.isEmpty else { throw AppError.emptyName }
        let circle = Circle(
            id: UUID(),
            name: trimmed,
            inviteCode: InviteCode.make(existing: Set(snapshot.circles.map(\.inviteCode))),
            ownerID: pal.id,
            createdAt: .now,
            updatedAt: .now,
            memberships: [Membership(id: UUID(), palID: pal.id, joinedAt: .now, leftAt: nil)]
        )
        snapshot.circles.append(circle)
        commit()
        return circle
    }

    func join(code raw: String) async throws {
        guard let pal = snapshot.activePal else { throw AppError.needProfile }
        let code = InviteCode.normalize(raw)
        guard code.count == 6 else { throw AppError.codeNotFound }
        if let index = snapshot.circles.firstIndex(where: { $0.inviteCode == code }) {
            try addActivePal(toCircleAt: index)
            return
        }
        guard sync.kind == .cloudKit else { throw AppError.codeNotFound }
        do {
            guard let bundle = try await sync.bundle(inviteCode: code) else { throw AppError.codeNotFound }
            snapshot.apply(bundle)
            guard let index = snapshot.circles.firstIndex(where: { $0.inviteCode == code }) else {
                throw AppError.codeNotFound
            }
            if snapshot.circles[index].containsCurrent(pal.id) {
                commit()
                throw AppError.alreadyMember
            }
            try addActivePal(toCircleAt: index)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.sync(SyncFailure.wrap(error).message)
        }
    }

    func addPal(_ palID: UUID, to circleID: UUID) throws {
        guard snapshot.pals.contains(where: { $0.id == palID }) else { throw AppError.notInCircle }
        guard snapshot.circles.contains(where: { $0.id == circleID }) else { throw AppError.codeNotFound }
        guard let index = snapshot.circles.firstIndex(where: { $0.id == circleID }) else { return }
        if snapshot.circles[index].containsCurrent(palID) { throw AppError.alreadyMember }
        snapshot.circles[index].memberships.append(
            Membership(id: UUID(), palID: palID, joinedAt: .now, leftAt: nil)
        )
        snapshot.circles[index].updatedAt = .now
        commit()
    }

    func leaveCircle(_ id: UUID) {
        guard let palID = snapshot.activePalID,
              let index = snapshot.circles.firstIndex(where: { $0.id == id }) else { return }
        for membershipIndex in snapshot.circles[index].memberships.indices {
            let membership = snapshot.circles[index].memberships[membershipIndex]
            if membership.palID == palID, membership.leftAt == nil {
                snapshot.circles[index].memberships[membershipIndex].leftAt = .now
            }
        }
        snapshot.circles[index].updatedAt = .now
        if snapshot.circles[index].currentPalIDs.isEmpty {
            deleteCircle(id)
            return
        }
        if snapshot.circles[index].ownerID == palID, let nextOwner = snapshot.circles[index].currentPalIDs.first {
            snapshot.circles[index].ownerID = nextOwner
        }
        commit()
    }

    func deleteCircle(_ id: UUID) {
        let habitIDs = snapshot.habits.filter { $0.circleID == id }.map(\.id)
        for habitID in habitIDs {
            removeHabit(habitID)
        }
        snapshot.circles.removeAll { $0.id == id }
        commit()
    }

    func saveHabit(_ draft: HabitDraft) throws {
        guard let pal = snapshot.activePal else { throw AppError.needProfile }
        let title = clean(draft.title, limit: 40)
        guard !title.isEmpty else { throw AppError.emptyName }
        if let id = draft.id, let index = snapshot.habits.firstIndex(where: { $0.id == id }) {
            snapshot.habits[index].title = title
            snapshot.habits[index].symbolName = draft.symbolName
            snapshot.habits[index].colorHex = draft.colorHex
            snapshot.habits[index].reminderEnabled = draft.reminderEnabled
            snapshot.habits[index].reminderHour = draft.reminderHour
            snapshot.habits[index].reminderMinute = draft.reminderMinute
            snapshot.habits[index].updatedAt = .now
            commit()
            return
        }
        if let circleID = draft.circleID {
            guard let circle = snapshot.circle(circleID), circle.containsCurrent(pal.id) else {
                throw AppError.notInCircle
            }
        }
        snapshot.habits.append(
            Habit(
                id: UUID(),
                title: title,
                symbolName: draft.symbolName,
                colorHex: draft.colorHex,
                circleID: draft.circleID,
                ownerID: pal.id,
                createdAt: .now,
                updatedAt: .now,
                reminderEnabled: draft.reminderEnabled,
                reminderHour: draft.reminderHour,
                reminderMinute: draft.reminderMinute
            )
        )
        commit()
    }

    func deleteHabit(_ id: UUID) {
        removeHabit(id)
        commit()
    }

    func checkIn(habitID: UUID, note: String, photoJPEG: Data?, clearPhoto: Bool) throws {
        var working = snapshot
        let write = try Journal.checkIn(
            snapshot: &working,
            habitID: habitID,
            note: note,
            attachPhoto: photoJPEG != nil,
            clearPhoto: clearPhoto
        )
        if let data = photoJPEG, let filename = write.photoFilename {
            persistence.savePhoto(data, filename: filename)
        }
        if let removed = write.removedPhotoFilename {
            persistence.deletePhoto(filename: removed)
        }
        snapshot = working
        commit()
        if write.securedToday {
            celebrationText = write.habitTitle
            celebrationID = UUID()
        }
    }

    func photoData(filename: String) -> Data? {
        persistence.photoData(filename: filename)
    }

    func refresh() async {
        let token = revision
        reloadFromDisk()
        guard backend == .cloudKit else { return }
        if syncing {
            syncQueued = true
            return
        }
        syncing = true
        do {
            var next = snapshot
            next = try await sync.push(next)
            if Task.isCancelled {
                syncing = false
                return
            }
            next = try await sync.pull(into: next)
            if revision == token {
                snapshot = next
                persistence.save(snapshot)
                lastSyncError = nil
                lastSyncedAt = .now
                reschedule()
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                syncQueued = true
            }
        } catch {
            lastSyncError = SyncFailure.wrap(error).message
        }
        syncing = false
        if syncQueued {
            syncQueued = false
            await refresh()
        }
    }

    func summary(for habit: Habit, now: Date = .now) -> StreakSummary {
        StreakEngine.summary(
            habit: habit,
            circle: snapshot.circle(for: habit),
            checkIns: snapshot.checkIns,
            now: now
        )
    }

    func youCheckedIn(_ habit: Habit, now: Date = .now) -> Bool {
        guard let palID = snapshot.activePalID else { return false }
        return snapshot.checkedIn(habitID: habit.id, palID: palID, dayKey: DayKey.string(from: now))
    }

    func statusLine(for habit: Habit, now: Date = .now) -> String {
        let summary = summary(for: habit, now: now)
        let names = summary.waitingPalIDs.compactMap { snapshot.pal($0)?.displayName }
        let solo = habit.circleID == nil || summary.requiredToday <= 1
        return StatusCopy.line(
            summary: summary,
            waitingNames: names,
            youCheckedIn: youCheckedIn(habit, now: now),
            solo: solo
        )
    }

    func members(for habit: Habit, now: Date = .now) -> [MemberState] {
        let circle = snapshot.circle(for: habit)
        let ids = StreakEngine.requiredPalIDs(habit: habit, circle: circle, day: now)
        let dayKey = DayKey.string(from: now)
        return ids.map { id in
            let pal = snapshot.pal(id) ?? Pal(
                id: id,
                displayName: "Pal",
                colorHex: "8C6B5E",
                createdAt: .now,
                updatedAt: .now,
                isLocalProfile: false
            )
            return MemberState(
                pal: pal,
                checkedIn: snapshot.checkedIn(habitID: habit.id, palID: id, dayKey: dayKey)
            )
        }
    }

    var headlineStreak: Int {
        guard let palID = snapshot.activePalID else { return 0 }
        return snapshot.habits(for: palID).map { summary(for: $0).current }.max() ?? 0
    }

    func greeting(now: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    func recentDays(for habit: Habit, count: Int = 7, now: Date = .now) -> [DayDot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let index = CheckInIndex(checkIns: snapshot.checkIns)
        let circle = snapshot.circle(for: habit)
        return (0..<count).reversed().compactMap { offset -> DayDot? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let started = calendar.startOfDay(for: habit.createdAt) <= day
            let complete = started && StreakEngine.isDayComplete(
                habit: habit,
                circle: circle,
                day: day,
                index: index,
                calendar: calendar
            )
            let symbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
            return DayDot(
                id: DayKey.string(from: day, calendar: calendar),
                label: String(symbol.prefix(1)),
                complete: complete,
                isToday: offset == 0,
                started: started
            )
        }
    }

    private func addActivePal(toCircleAt index: Int) throws {
        guard let pal = snapshot.activePal else { throw AppError.needProfile }
        if snapshot.circles[index].containsCurrent(pal.id) {
            throw AppError.alreadyMember
        }
        snapshot.circles[index].memberships.append(
            Membership(id: UUID(), palID: pal.id, joinedAt: .now, leftAt: nil)
        )
        snapshot.circles[index].updatedAt = .now
        commit()
    }

    private func removeHabit(_ id: UUID) {
        let doomed = snapshot.checkIns.filter { $0.habitID == id }
        for item in doomed {
            if let filename = item.photoFilename {
                persistence.deletePhoto(filename: filename)
            }
            snapshot.noteDeletedCheckIn(item.id, habitID: id)
        }
        snapshot.checkIns.removeAll { $0.habitID == id }
        snapshot.habits.removeAll { $0.id == id }
        snapshot.noteDeletedHabit(id)
    }

    private func commit() {
        revision += 1
        persistence.save(snapshot)
        reschedule()
        WidgetCenter.shared.reloadAllTimelines()
        guard backend == .cloudKit else { return }
        Task { await refresh() }
    }

    private func reschedule() {
        guard schedulesReminders else { return }
        ReminderScheduler.reschedule(snapshot: snapshot)
    }

    private func clean(_ raw: String, limit: Int) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }
}

struct DayDot: Identifiable, Equatable {
    var id: String
    var label: String
    var complete: Bool
    var isToday: Bool
    var started: Bool
}
