import AppIntents
import Foundation

struct HabitEntity: AppEntity, Identifiable, Hashable {
    var id: String
    var title: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static var defaultQuery = HabitQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct HabitQuery: EntityQuery {
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        let habits = WidgetPayload.load()?.habits ?? []
        return habits
            .filter { identifiers.contains($0.id.uuidString) }
            .map { HabitEntity(id: $0.id.uuidString, title: $0.title) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        let habits = WidgetPayload.load()?.habits ?? []
        return habits.map { HabitEntity(id: $0.id.uuidString, title: $0.title) }
    }

    func defaultResult() async -> HabitEntity? {
        guard let habit = WidgetPayload.load()?.habits.first(where: { !$0.checkedIn })
                ?? WidgetPayload.load()?.habits.first else {
            return nil
        }
        return HabitEntity(id: habit.id.uuidString, title: habit.title)
    }
}

struct SelectHabitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Habit"
    static var description = IntentDescription("Pick the habit to pin on the Home Screen.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?
}
