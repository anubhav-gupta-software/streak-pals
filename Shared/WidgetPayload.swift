import Foundation

struct WidgetHabit: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var symbolName: String
    var colorHex: String
    var currentStreak: Int
    var checkedIn: Bool
    var waitingCount: Int
    var detail: String
    var solo: Bool

    static let placeholder = WidgetHabit(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        title: "Gym",
        symbolName: "dumbbell.fill",
        colorHex: "E23D12",
        currentStreak: 6,
        checkedIn: false,
        waitingCount: 1,
        detail: "Waiting on 1",
        solo: false
    )
}

struct WidgetPayload: Codable, Equatable {
    var generatedAt: Date
    var palName: String
    var habits: [WidgetHabit]

    static func build(from snapshot: AppSnapshot, now: Date = .now) -> WidgetPayload {
        guard let pal = snapshot.activePal else {
            return WidgetPayload(generatedAt: now, palName: "", habits: [])
        }
        let habits = snapshot.habits(for: pal.id).map { habit in
            let circle = snapshot.circle(for: habit)
            let summary = StreakEngine.summary(
                habit: habit,
                circle: circle,
                checkIns: snapshot.checkIns,
                now: now
            )
            let dayKey = DayKey.string(from: now)
            let checkedIn = snapshot.checkedIn(habitID: habit.id, palID: pal.id, dayKey: dayKey)
            let solo = habit.circleID == nil || summary.requiredToday <= 1
            return WidgetHabit(
                id: habit.id,
                title: habit.title,
                symbolName: habit.symbolName,
                colorHex: habit.colorHex,
                currentStreak: summary.current,
                checkedIn: checkedIn,
                waitingCount: summary.waitingPalIDs.count,
                detail: StatusCopy.widgetDetail(summary: summary, youCheckedIn: checkedIn, solo: solo),
                solo: solo
            )
        }
        return WidgetPayload(generatedAt: now, palName: pal.displayName, habits: habits)
    }

    static func load() -> WidgetPayload? {
        guard let container = AppGroup.containerURL else { return nil }
        let url = container.appendingPathComponent("widget-payload.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.snapshot.decode(WidgetPayload.self, from: data)
    }
}
