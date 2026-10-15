import Foundation

enum Palette {
    static let habitColors = [
        "E23D12", "F08A12", "E2B007", "2F9E6B",
        "1F8A9E", "3D5FD1", "8A4AD4", "D43D78"
    ]

    static let palColors = [
        "E23D12", "1F8A9E", "2F9E6B", "8A4AD4",
        "D43D78", "E2B007", "3D5FD1", "F08A12"
    ]

    static let symbols = [
        "flame.fill", "figure.run", "dumbbell.fill", "drop.fill",
        "book.fill", "moon.fill", "fork.knife", "heart.fill",
        "brain.head.profile", "pencil", "leaf.fill", "bed.double.fill",
        "cup.and.saucer.fill", "pills.fill", "music.note", "camera.fill"
    ]
}

struct HabitDraft: Equatable, Identifiable {
    /// Identity for the editor sheet. Not the habit's id.
    var id = UUID()
    var habitID: UUID?
    var title: String = ""
    var symbolName: String = Palette.symbols[0]
    var colorHex: String = Palette.habitColors[0]
    var circleID: UUID?
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
}

enum AppError: LocalizedError, Equatable {
    case emptyName
    case alreadyMember
    case codeNotFound
    case notInCircle
    case needProfile
    case habitMissing
    case sync(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Give it a name first."
        case .alreadyMember:
            return "You're already in this circle."
        case .codeNotFound:
            return "No circle on this iPhone uses that code. Another phone can join only after CloudKit sync is turned on."
        case .notInCircle:
            return "You need to be in the circle first."
        case .needProfile:
            return "Add your name first."
        case .habitMissing:
            return "That habit is gone."
        case .sync(let message):
            return message
        }
    }
}

struct HabitIDBox: Identifiable, Hashable {
    var id: UUID
}

struct MemberState: Identifiable, Equatable {
    var pal: Pal
    var checkedIn: Bool
    var id: UUID { pal.id }
}
