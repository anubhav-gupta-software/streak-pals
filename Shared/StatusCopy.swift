import Foundation

enum StatusCopy {
    static func line(
        summary: StreakSummary,
        waitingNames: [String],
        youCheckedIn: Bool,
        solo: Bool
    ) -> String {
        if summary.todayComplete {
            return solo ? "You're in. Today counts." : "Everyone's in. Today counts."
        }
        if summary.current == 0 && !youCheckedIn {
            return solo ? "Check in to light the streak." : "The streak stays lit only if every pal checks in."
        }
        if youCheckedIn && summary.waitingPalIDs.isEmpty {
            return "You're in. Today counts."
        }
        if waitingNames.count == 1 {
            return "Waiting on \(waitingNames[0])."
        }
        if waitingNames.count == 2 {
            return "Waiting on \(waitingNames[0]) and \(waitingNames[1])."
        }
        if waitingNames.count > 2 {
            return "Waiting on \(waitingNames[0]) and \(waitingNames.count - 1) others."
        }
        if summary.waitingPalIDs.count == 1 {
            return "Waiting on 1 pal."
        }
        if summary.waitingPalIDs.count > 1 {
            return "Waiting on \(summary.waitingPalIDs.count) pals."
        }
        return "Check in to keep it alive."
    }

    static func widgetDetail(summary: StreakSummary, youCheckedIn: Bool, solo: Bool) -> String {
        if summary.todayComplete { return solo ? "Today counts" : "Everyone's in" }
        if youCheckedIn { return summary.waitingPalIDs.isEmpty ? "Checked in" : "Waiting on \(summary.waitingPalIDs.count)" }
        if summary.isAtRisk { return "Don't let it go out" }
        return "Check in"
    }
}
