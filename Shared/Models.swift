import Foundation

struct Pal: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var displayName: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    /// Profiles created on this phone can be switched to. Pals that arrived
    /// through sync stay false so they don't show up in the switcher.
    var isLocalProfile: Bool

    var initial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }
}

struct Membership: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var palID: UUID
    var joinedAt: Date
    var leftAt: Date?

    func covers(_ day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        guard calendar.startOfDay(for: joinedAt) <= start else { return false }
        if let leftAt, calendar.startOfDay(for: leftAt) <= start { return false }
        return true
    }
}

struct Circle: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var inviteCode: String
    var ownerID: UUID
    var createdAt: Date
    var updatedAt: Date
    var memberships: [Membership]

    func activePalIDs(on day: Date, calendar: Calendar = .current) -> [UUID] {
        var ids: [UUID] = []
        var seen = Set<UUID>()
        for membership in memberships where membership.covers(day, calendar: calendar) {
            if seen.insert(membership.palID).inserted {
                ids.append(membership.palID)
            }
        }
        return ids
    }

    var currentPalIDs: [UUID] {
        var ids: [UUID] = []
        var seen = Set<UUID>()
        for membership in memberships where membership.leftAt == nil {
            if seen.insert(membership.palID).inserted {
                ids.append(membership.palID)
            }
        }
        return ids
    }

    func containsCurrent(_ palID: UUID) -> Bool {
        currentPalIDs.contains(palID)
    }

    func merging(_ other: Circle) -> Circle {
        var byID: [UUID: Membership] = [:]
        for membership in memberships + other.memberships {
            if var existing = byID[membership.id] {
                existing.joinedAt = min(existing.joinedAt, membership.joinedAt)
                existing.leftAt = Self.earliestLeave(existing.leftAt, membership.leftAt)
                byID[membership.id] = existing
            } else {
                byID[membership.id] = membership
            }
        }
        let newer = updatedAt >= other.updatedAt ? self : other
        var copy = newer
        copy.createdAt = min(createdAt, other.createdAt)
        copy.updatedAt = max(updatedAt, other.updatedAt)
        copy.memberships = byID.values.sorted { $0.joinedAt < $1.joinedAt }
        return copy
    }

    private static func earliestLeave(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (nil, nil):
            return nil
        case let (date?, nil), let (nil, date?):
            return date
        case let (lhs?, rhs?):
            return min(lhs, rhs)
        }
    }
}

struct Habit: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var symbolName: String
    var colorHex: String
    /// Nil means it's personal. Only the owner has to check in.
    var circleID: UUID?
    var ownerID: UUID
    var createdAt: Date
    var updatedAt: Date
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    func merging(_ other: Habit) -> Habit {
        var newer = updatedAt >= other.updatedAt ? self : other
        newer.createdAt = min(createdAt, other.createdAt)
        newer.updatedAt = max(updatedAt, other.updatedAt)
        return newer
    }
}

struct CheckIn: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var habitID: UUID
    var palID: UUID
    var dayKey: String
    var note: String
    var photoFilename: String?
    var createdAt: Date
}

struct AppSnapshot: Codable, Equatable {
    var pals: [Pal] = []
    var circles: [Circle] = []
    var habits: [Habit] = []
    var checkIns: [CheckIn] = []
    var activePalID: UUID?
    var remindersEnabled: Bool = true
    /// Kept so a delete on one phone isn't uploaded again by another.
    var deletedHabitIDs: [UUID] = []
    /// Check-in ids keyed by habit id, so one habit's deletes don't wipe another.
    var deletedCheckInsByHabit: [String: [UUID]] = [:]

    static let empty = AppSnapshot()

    enum CodingKeys: String, CodingKey {
        case pals, circles, habits, checkIns, activePalID, remindersEnabled
        case deletedHabitIDs, deletedCheckInsByHabit, deletedCheckInIDs
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pals = try container.decodeIfPresent([Pal].self, forKey: .pals) ?? []
        circles = try container.decodeIfPresent([Circle].self, forKey: .circles) ?? []
        habits = try container.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        checkIns = try container.decodeIfPresent([CheckIn].self, forKey: .checkIns) ?? []
        activePalID = try container.decodeIfPresent(UUID.self, forKey: .activePalID)
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        deletedHabitIDs = try container.decodeIfPresent([UUID].self, forKey: .deletedHabitIDs) ?? []
        deletedCheckInsByHabit = try container.decodeIfPresent([String: [UUID]].self, forKey: .deletedCheckInsByHabit) ?? [:]
        if deletedCheckInsByHabit.isEmpty,
           let legacy = try container.decodeIfPresent([UUID].self, forKey: .deletedCheckInIDs) {
            deletedCheckInsByHabit["legacy"] = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pals, forKey: .pals)
        try container.encode(circles, forKey: .circles)
        try container.encode(habits, forKey: .habits)
        try container.encode(checkIns, forKey: .checkIns)
        try container.encodeIfPresent(activePalID, forKey: .activePalID)
        try container.encode(remindersEnabled, forKey: .remindersEnabled)
        try container.encode(deletedHabitIDs, forKey: .deletedHabitIDs)
        try container.encode(deletedCheckInsByHabit, forKey: .deletedCheckInsByHabit)
    }

    var activePal: Pal? {
        guard let activePalID else { return nil }
        return pal(activePalID)
    }

    func pal(_ id: UUID) -> Pal? {
        pals.first { $0.id == id }
    }

    func circle(_ id: UUID) -> Circle? {
        circles.first { $0.id == id }
    }

    func habit(_ id: UUID) -> Habit? {
        habits.first { $0.id == id }
    }

    func circle(for habit: Habit) -> Circle? {
        habit.circleID.flatMap { circle($0) }
    }

    func habits(for palID: UUID) -> [Habit] {
        habits
            .filter { isVisible($0, to: palID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func isVisible(_ habit: Habit, to palID: UUID) -> Bool {
        if let circleID = habit.circleID, let circle = circle(circleID) {
            return circle.containsCurrent(palID)
        }
        return habit.ownerID == palID
    }

    func checkedIn(habitID: UUID, palID: UUID, dayKey: String) -> Bool {
        checkIns.contains { $0.habitID == habitID && $0.palID == palID && $0.dayKey == dayKey }
    }

    func checkIn(habitID: UUID, palID: UUID, dayKey: String) -> CheckIn? {
        checkIns.first { $0.habitID == habitID && $0.palID == palID && $0.dayKey == dayKey }
    }

    mutating func upsertPal(_ remote: Pal) {
        guard let index = pals.firstIndex(where: { $0.id == remote.id }) else {
            var arriving = remote
            arriving.isLocalProfile = false
            pals.append(arriving)
            return
        }
        var local = pals[index]
        let keepLocalProfile = local.isLocalProfile
        if remote.updatedAt >= local.updatedAt {
            local = remote
            local.isLocalProfile = keepLocalProfile || remote.isLocalProfile
        }
        pals[index] = local
    }

    mutating func upsertCircle(_ remote: Circle) {
        if let index = circles.firstIndex(where: { $0.id == remote.id }) {
            circles[index] = circles[index].merging(remote)
            return
        }
        guard let index = circles.firstIndex(where: { $0.inviteCode == remote.inviteCode }) else {
            circles.append(remote)
            return
        }
        let previousID = circles[index].id
        var merged = circles[index].merging(remote)
        merged.id = remote.id
        circles[index] = merged
        if previousID != remote.id {
            for habitIndex in habits.indices where habits[habitIndex].circleID == previousID {
                habits[habitIndex].circleID = remote.id
            }
        }
    }

    mutating func upsertHabit(_ remote: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == remote.id }) else {
            habits.append(remote)
            return
        }
        habits[index] = habits[index].merging(remote)
    }

    mutating func apply(_ bundle: CircleBundle) {
        upsertCircle(bundle.circle)
        for pal in bundle.pals {
            upsertPal(pal)
        }
        for habit in bundle.habits where !deletedHabitIDs.contains(habit.id) {
            upsertHabit(habit)
        }
        for checkIn in bundle.checkIns where !isCheckInDeleted(checkIn.id) {
            upsertCheckIn(checkIn)
        }
    }

    func isCheckInDeleted(_ id: UUID) -> Bool {
        deletedCheckInsByHabit.values.contains { $0.contains(id) }
    }

    mutating func noteDeletedCheckIn(_ id: UUID, habitID: UUID) {
        var list = deletedCheckInsByHabit[habitID.uuidString] ?? []
        if !list.contains(id) {
            list.append(id)
        }
        deletedCheckInsByHabit[habitID.uuidString] = list
    }

    mutating func noteDeletedHabit(_ id: UUID) {
        if !deletedHabitIDs.contains(id) {
            deletedHabitIDs.append(id)
        }
    }

    mutating func upsertCheckIn(_ remote: CheckIn) {
        if checkIns.contains(where: { $0.id == remote.id }) { return }
        if let index = checkIns.firstIndex(where: {
            $0.habitID == remote.habitID && $0.palID == remote.palID && $0.dayKey == remote.dayKey
        }) {
            if remote.createdAt < checkIns[index].createdAt {
                checkIns[index] = remote
            }
            return
        }
        checkIns.append(remote)
    }
}

enum InviteCode {
    static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func normalize(_ raw: String) -> String {
        let allowed = Set(alphabet)
        let filtered = raw.uppercased().filter { allowed.contains($0) }
        return String(filtered.prefix(6))
    }

    static func make(existing: Set<String>) -> String {
        for _ in 0..<40 {
            let code = String((0..<6).compactMap { _ in alphabet.randomElement() })
            if code.count == 6, !existing.contains(code) {
                return code
            }
        }
        var fallback = ""
        while fallback.count < 6 {
            fallback.append(alphabet[Int.random(in: 0..<alphabet.count)])
        }
        return fallback
    }
}
