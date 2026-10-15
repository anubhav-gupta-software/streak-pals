import Foundation

struct HeatCell: Identifiable, Equatable {
    var id: String
    var fraction: Double
    var hasHabits: Bool
}

struct HabitStat: Identifiable, Equatable {
    var id: UUID
    var habit: Habit
    var summary: StreakSummary
}

struct StatsModel: Equatable {
    var longest: Int
    var currentBest: Int
    var checkInCount: Int
    var perfectDays: Int
    var weeks: [[HeatCell?]]
    var habits: [HabitStat]

    static func build(snapshot: AppSnapshot, weeksBack: Int = 16, now: Date = .now) -> StatsModel {
        guard let palID = snapshot.activePalID else {
            return StatsModel(longest: 0, currentBest: 0, checkInCount: 0, perfectDays: 0, weeks: [], habits: [])
        }
        let calendar = Calendar.current
        let habits = snapshot.habits(for: palID)
        let index = CheckInIndex(checkIns: snapshot.checkIns)
        let stats = habits.map { habit in
            HabitStat(
                id: habit.id,
                habit: habit,
                summary: StreakEngine.summary(habit: habit, circle: snapshot.circle(for: habit), checkIns: snapshot.checkIns, now: now)
            )
        }
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let startOfThisWeek = calendar.date(byAdding: .day, value: -delta, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -7 * (weeksBack - 1), to: startOfThisWeek) ?? today

        var perfect = 0
        if let earliest = habits.map({ calendar.startOfDay(for: $0.createdAt) }).min() {
            var day = earliest
            while day <= today {
                let active = habits.filter { calendar.startOfDay(for: $0.createdAt) <= day }
                if !active.isEmpty {
                    let done = active.filter {
                        StreakEngine.isDayComplete(
                            habit: $0,
                            circle: snapshot.circle(for: $0),
                            day: day,
                            index: index,
                            calendar: calendar
                        )
                    }.count
                    if done == active.count { perfect += 1 }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }

        var columns: [[HeatCell?]] = []
        var cursor = start
        for _ in 0..<weeksBack {
            var column: [HeatCell?] = []
            for _ in 0..<7 {
                if cursor > today {
                    column.append(nil)
                } else {
                    let active = habits.filter { calendar.startOfDay(for: $0.createdAt) <= cursor }
                    let key = DayKey.string(from: cursor, calendar: calendar)
                    if active.isEmpty {
                        column.append(HeatCell(id: key, fraction: 0, hasHabits: false))
                    } else {
                        let done = active.filter {
                            StreakEngine.isDayComplete(
                                habit: $0,
                                circle: snapshot.circle(for: $0),
                                day: cursor,
                                index: index,
                                calendar: calendar
                            )
                        }.count
                        let fraction = Double(done) / Double(active.count)
                        column.append(HeatCell(id: key, fraction: fraction, hasHabits: true))
                    }
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            columns.append(column)
        }

        return StatsModel(
            longest: stats.map(\.summary.longest).max() ?? 0,
            currentBest: stats.map(\.summary.current).max() ?? 0,
            checkInCount: snapshot.checkIns.filter { $0.palID == palID }.count,
            perfectDays: perfect,
            weeks: columns,
            habits: stats
        )
    }
}
