import AppIntents
import Foundation
import WidgetKit

struct CheckInHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Check In"
    static var description = IntentDescription("Check in to a habit for today.")
    static var openAppWhenRun = false

    @Parameter(title: "Habit")
    var habitID: String

    init() {
        habitID = ""
    }

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: habitID) else {
            return .result(dialog: "Open Streak Pals to check in.")
        }
        let store = SnapshotStore()
        guard store.usesAppGroup else {
            return .result(dialog: "Open Streak Pals to check in.")
        }
        do {
            let write = try store.checkInActivePal(habitID: id)
            WidgetCenter.shared.reloadAllTimelines()
            if write.alreadyDone {
                return .result(dialog: "You're already checked in.")
            }
            if write.securedToday {
                return .result(dialog: "Today counts. The streak holds.")
            }
            return .result(dialog: "Checked in.")
        } catch {
            return .result(dialog: "Open Streak Pals to check in.")
        }
    }
}
