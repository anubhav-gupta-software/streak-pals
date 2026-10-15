import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                let model = StatsModel.build(snapshot: store.snapshot)
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(store.snapshot.activePal?.displayName ?? "")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        FlameView(streak: model.currentBest, lit: model.currentBest > 0, size: 48)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 10) {
                        StatTile(value: "\(model.currentBest)", label: "Current")
                        StatTile(value: "\(model.longest)", label: "Longest")
                        StatTile(value: "\(model.checkInCount)", label: "Check-ins")
                    }
                    StatTile(value: "\(model.perfectDays)", label: "Perfect days", wide: true)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 16 weeks")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Heatmap(weeks: model.weeks)
                        HStack(spacing: 8) {
                            Text("Missed")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                            RoundedRectangle(cornerRadius: 2).fill(Theme.ember.opacity(0.12)).frame(width: 10, height: 10)
                            RoundedRectangle(cornerRadius: 2).fill(Theme.ember.opacity(0.45)).frame(width: 10, height: 10)
                            RoundedRectangle(cornerRadius: 2).fill(Theme.ember).frame(width: 10, height: 10)
                            Text("Everyone in")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Habits")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        if model.habits.isEmpty {
                            Text("Check in a few times and this fills in.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        ForEach(model.habits) { stat in
                            HStack(spacing: 12) {
                                SymbolBadge(symbol: stat.habit.symbolName, hex: stat.habit.colorHex, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stat.habit.title)
                                        .foregroundStyle(Theme.ink)
                                    Text("\(stat.summary.securedDays) secured \(stat.summary.securedDays == 1 ? "day" : "days")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Text("\(stat.summary.current)")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(stat.summary.current > 0 ? Theme.ember : Theme.muted)
                            }
                        }
                    }
                    .padding(16)
                    .cardStyle()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
        }
    }
}

private struct StatTile: View {
    var value: String
    var label: String
    var wide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}

private struct Heatmap: View {
    var weeks: [[HeatCell?]]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 3) {
                ForEach(weekdayLabels.indices, id: \.self) { index in
                    Text(weekdayLabels[index])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 12, height: 12)
                }
            }
            .accessibilityHidden(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                cell(row < weeks[week].count ? weeks[week][row] : nil)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Check-in history for the last 16 weeks")
    }

    // Weekday labels stay aligned with the columns built in StatsModel.

    private var weekdayLabels: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return (0..<7).map { offset in
            symbols[(first + offset) % symbols.count]
        }
    }

    private func cell(_ value: HeatCell?) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(value))
            .frame(width: 12, height: 12)
    }

    private func color(_ value: HeatCell?) -> Color {
        guard let value else { return Color.clear }
        guard value.hasHabits else { return Theme.line.opacity(0.8) }
        if value.fraction <= 0 { return Theme.ember.opacity(0.14) }
        if value.fraction < 1 { return Theme.ember.opacity(0.5) }
        return Theme.ember
    }
}

