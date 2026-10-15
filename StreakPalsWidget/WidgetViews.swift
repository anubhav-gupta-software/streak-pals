import SwiftUI
import WidgetKit

struct HabitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HabitEntry

    var body: some View {
        Group {
            if let habit = entry.habit, entry.hasPayload {
                switch family {
                case .accessoryCircular:
                    circular(habit)
                case .accessoryRectangular:
                    rectangular(habit)
                default:
                    small(habit)
                }
            } else {
                fallback
            }
        }
        .widgetURL(link)
    }

    private var link: URL? {
        if let habit = entry.habit {
            return URL(string: "streakpals://checkin/\(habit.id.uuidString)")
        }
        return URL(string: "streakpals://today")
    }

    private func small(_ habit: WidgetHabit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: habit.symbolName)
                    .foregroundStyle(WidgetTheme.color(habit.colorHex))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                    Text("\(habit.currentStreak)")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(habit.currentStreak > 0 ? WidgetTheme.ember : WidgetTheme.muted)
            }
            Spacer(minLength: 0)
            Text(habit.title)
                .font(.headline)
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(2)
            HStack {
                Text(habit.detail)
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(1)
                Spacer()
                checkButton(habit)
            }
        }
    }

    private func circular(_ habit: WidgetHabit) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill")
            Text("\(habit.currentStreak)")
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .widgetAccentable()
    }

    private func rectangular(_ habit: WidgetHabit) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(habit.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(habit.detail)
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(habit.currentStreak)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .widgetAccentable()
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(WidgetTheme.ember)
            Text("Streak Pals")
                .font(.headline)
                .foregroundStyle(WidgetTheme.ink)
            Text(entry.usesAppGroup ? "Open the app to add a habit." : "Open the app to check in.")
                .font(.caption)
                .foregroundStyle(WidgetTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func checkButton(_ habit: WidgetHabit) -> some View {
        if habit.checkedIn {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(WidgetTheme.ember)
        } else if entry.usesAppGroup {
            Button(intent: CheckInHabitIntent(habitID: habit.id)) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(WidgetTheme.ember)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Check in to \(habit.title)")
        }
    }
}

struct BoardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BoardEntry

    private var visible: [WidgetHabit] {
        let limit = family == .systemLarge ? 6 : 3
        return Array(entry.habits.prefix(limit))
    }

    var body: some View {
        Group {
            if entry.hasPayload, !visible.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(entry.palName.isEmpty ? "Today" : entry.palName)
                            .font(.headline)
                            .foregroundStyle(WidgetTheme.ink)
                        Spacer()
                        Image(systemName: "flame.fill")
                            .foregroundStyle(WidgetTheme.ember)
                    }
                    ForEach(visible) { habit in
                        row(habit)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Streak Pals")
                        .font(.headline)
                        .foregroundStyle(WidgetTheme.ink)
                    Text(entry.usesAppGroup
                         ? "Add a habit in the app and it will show up here."
                         : "Checking in from here needs the App Group. Open the app to check in.")
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(URL(string: "streakpals://today"))
    }

    private func row(_ habit: WidgetHabit) -> some View {
        HStack(spacing: 8) {
            Image(systemName: habit.symbolName)
                .foregroundStyle(WidgetTheme.color(habit.colorHex))
                .frame(width: 18)
            Text(habit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(habit.currentStreak)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(WidgetTheme.ink)
            if habit.checkedIn {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WidgetTheme.ember)
            } else if entry.usesAppGroup {
                Button(intent: CheckInHabitIntent(habitID: habit.id)) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(WidgetTheme.ember)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Check in to \(habit.title)")
            }
        }
    }
}
