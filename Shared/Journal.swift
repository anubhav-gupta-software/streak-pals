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
    /// A previous photo the caller should delete from disk.
    var removedPhotoFilename: String?
}

enum Journal {
    /// Records today's check-in for the active pal. A shared habit counts for
    /// the streak only after every current member has one for that day.
    static func checkIn(
        snapshot: inout AppSnapshot,
        habitID: UUID,
        note: String,
        attachPhoto: Bool,
        clearPhoto: Bool = false,
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
        let removedPhoto = clearPhoto ? existing?.photoFilename : nil
        let recordID = existing?.id ?? UUID()

        let storedFilename: String?
        if clearPhoto {
            storedFilename = nil
        } else if attachPhoto {
            storedFilename = existing?.photoFilename ?? "\(recordID.uuidString).jpg"
        } else {
            storedFilename = existing?.photoFilename
        }

        if let index = existing.flatMap({ item in snapshot.checkIns.firstIndex { $0.id == item.id } }) {
            snapshot.checkIns[index].note = trimmedNote
            snapshot.checkIns[index].photoFilename = storedFilename
        } else {
            snapshot.checkIns.append(
                CheckIn(
                    id: recordID,
                    habitID: habitID,
                    palID: palID,
                    dayKey: dayKey,
                    note: trimmedNote,
                    photoFilename: storedFilename,
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
            photoFilename: attachPhoto && !clearPhoto ? storedFilename : nil,
            removedPhotoFilename: removedPhoto
        )
    }
}
