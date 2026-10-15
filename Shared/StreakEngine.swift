import Foundation

struct CheckInIndex: Equatable {
    private var byHabit: [UUID: [String: Set<UUID>]]

    init(checkIns: [CheckIn]) {
        var map: [UUID: [String: Set<UUID>]] = [:]
        for item in checkIns {
            map[item.habitID, default: [:]][item.dayKey, default: []].insert(item.palID)
        }
        byHabit = map
    }

    func pals(habitID: UUID, dayKey: String) -> Set<UUID> {
        byHabit[habitID]?[dayKey] ?? []
    }
}

struct StreakSummary: Equatable {
    var current: Int
    var longest: Int
    var todayComplete: Bool
    var waitingPalIDs: [UUID]
    var requiredToday: Int
    var checkedInToday: Int
    var securedDays: Int

    var isAtRisk: Bool { !todayComplete && current > 0 }

    static let empty = StreakSummary(
        current: 0,
        longest: 0,
        todayComplete: false,
        waitingPalIDs: [],
        requiredToday: 0,
        checkedInToday: 0,
        securedDays: 0
    )
}

enum StreakEngine {
    static func requiredPalIDs(
        habit: Habit,
        circle: Circle?,
        day: Date,
        calendar: Calendar = .current
    ) -> [UUID] {
        if let circle, habit.circleID == circle.id {
            let ids = circle.activePalIDs(on: day, calendar: calendar)
            if !ids.isEmpty { return ids }
        }
        return [habit.ownerID]
    }

    static func isDayComplete(
        habit: Habit,
        circle: Circle?,
        day: Date,
        index: CheckInIndex,
        calendar: Calendar = .current
    ) -> Bool {
        let required = requiredPalIDs(habit: habit, circle: circle, day: day, calendar: calendar)
        let done = index.pals(habitID: habit.id, dayKey: DayKey.string(from: day, calendar: calendar))
        return !required.isEmpty && required.allSatisfy { done.contains($0) }
    }

    static func summary(
        habit: Habit,
        circle: Circle?,
        checkIns: [CheckIn],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> StreakSummary {
        let index = CheckInIndex(checkIns: checkIns.filter { $0.habitID == habit.id })
        let today = calendar.startOfDay(for: now)
        let habitStart = calendar.startOfDay(for: habit.createdAt)
        guard habitStart <= today else { return .empty }

        var day = habitStart
        var run = 0
        var longest = 0
        var secured = 0

        while day < today {
            if isDayComplete(habit: habit, circle: circle, day: day, index: index, calendar: calendar) {
                run += 1
                secured += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }

        let requiredToday = requiredPalIDs(habit: habit, circle: circle, day: today, calendar: calendar)
        let doneToday = index.pals(habitID: habit.id, dayKey: DayKey.string(from: today, calendar: calendar))
        let waiting = requiredToday.filter { !doneToday.contains($0) }
        let todayComplete = !requiredToday.isEmpty && waiting.isEmpty
        var current = run
        if todayComplete {
            current += 1
            secured += 1
            longest = max(longest, current)
        }

        return StreakSummary(
            current: current,
            longest: longest,
            todayComplete: todayComplete,
            waitingPalIDs: waiting,
            requiredToday: requiredToday.count,
            checkedInToday: requiredToday.count - waiting.count,
            securedDays: secured
        )
    }
}
