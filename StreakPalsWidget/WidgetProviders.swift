import AppIntents
import WidgetKit

struct HabitTimeline: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: .now, habit: .placeholder, palName: "Alex", usesAppGroup: true, hasPayload: true)
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitEntry> {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry(for: configuration)], policy: .after(next))
    }

    func recommendations() -> [AppIntentRecommendation<SelectHabitIntent>] {
        []
    }

    private func entry(for configuration: SelectHabitIntent) -> HabitEntry {
        let group = AppGroup.containerURL != nil
        guard let payload = WidgetPayload.load() else {
            return HabitEntry(date: .now, habit: nil, palName: "", usesAppGroup: group, hasPayload: false)
        }
        let habit: WidgetHabit?
        if let selected = configuration.habit?.id {
            habit = payload.habits.first { $0.id.uuidString == selected } ?? payload.habits.first
        } else {
            habit = payload.habits.first { !$0.checkedIn } ?? payload.habits.first
        }
        return HabitEntry(date: .now, habit: habit, palName: payload.palName, usesAppGroup: true, hasPayload: true)
    }
}

struct BoardTimeline: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(
            date: .now,
            habits: [.placeholder],
            palName: "Alex",
            usesAppGroup: true,
            hasPayload: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> BoardEntry {
        let group = AppGroup.containerURL != nil
        guard let payload = WidgetPayload.load() else {
            return BoardEntry(date: .now, habits: [], palName: "", usesAppGroup: group, hasPayload: false)
        }
        return BoardEntry(
            date: .now,
            habits: payload.habits,
            palName: payload.palName,
            usesAppGroup: true,
            hasPayload: true
        )
    }
}
