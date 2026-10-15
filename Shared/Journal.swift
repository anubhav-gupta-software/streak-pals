import Foundation

enum JournalError: Error, Equatable {
    case habitMissing
    case notAllowed
    case noActivePal
}

struct CheckInWrite: Equatable {
    var habitTitle: String
    var alreadyDone: Bool
    var securedToday: Bool
    /// Set when the caller should write JPEG bytes under this filename.
    var photoFilename: String?
}

enum Journal {
    /// Records today's check-in for the active pal. A shared habit counts for
    /// the streak only after every current member has one for that day.
    static func checkIn(
        snapshot: inout AppSnapshot,
        habitID: UUID,
        note: String,
        attachPhoto: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> CheckInWrite {
        guard let palID = snapshot.activePalID else { throw JournalError.noActivePal }
        guard let habit = snapshot.habit(habitID) else { throw JournalError.habitMissing }
        guard snapshot.isVisible(habit, to: palID) else { throw JournalError.notAllowed }

        let trimmedNote = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let dayKey = DayKey.string(from: now, calendar: calendar)
        let circle = snapshot.circle(for: habit)
        let before = StreakEngine.summary(
            habit: habit,
            circle: circle,
            checkIns: snapshot.checkIns,
            now: now,
            calendar: calendar
        )
        let existing = snapshot.checkIn(habitID: habitID, palID: palID, dayKey: dayKey)

        let filename: String?
        if let existing {
            filename = attachPhoto ? (existing.photoFilename ?? "\(existing.id.uuidString).jpg") : existing.photoFilename
            if let index = snapshot.checkIns.firstIndex(where: { $0.id == existing.id }) {
                snapshot.checkIns[index].note = trimmedNote
                snapshot.checkIns[index].photoFilename = filename
            }
        } else {
            let id = UUID()
            filename = attachPhoto ? "\(id.uuidString).jpg" : nil
            snapshot.checkIns.append(
                CheckIn(
                    id: id,
                    habitID: habitID,
                    palID: palID,
                    dayKey: dayKey,
                    note: trimmedNote,
                    photoFilename: filename,
                    createdAt: now
                )
            )
        }

        let after = StreakEngine.summary(
            habit: habit,
            circle: circle,
            checkIns: snapshot.checkIns,
            now: now,
            calendar: calendar
        )
        return CheckInWrite(
            habitTitle: habit.title,
            alreadyDone: existing != nil,
            securedToday: !before.todayComplete && after.todayComplete,
            photoFilename: attachPhoto ? filename : nil
        )
    }
}
