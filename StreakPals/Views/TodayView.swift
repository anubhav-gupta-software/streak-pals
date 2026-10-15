import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var editor: HabitDraft?
    @State private var checkInID: HabitIDBox?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if habits.isEmpty {
                        empty
                    } else {
                        ForEach(habits) { habit in
                            HabitCard(habit: habit) {
                                checkInID = HabitIDBox(id: habit.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile and settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = HabitDraft()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New habit")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .habit(let id):
                    HabitDetailView(habitID: id)
                case .circle(let id):
                    CircleDetailView(circleID: id)
                }
            }
            .refreshable { await store.refresh() }
            .sheet(item: $editor) { draft in
                HabitEditor(draft: draft)
            }
            .sheet(item: $checkInID) { box in
                CheckInSheet(habitID: box.id)
            }
        }
    }

    private var habits: [Habit] {
        guard let palID = store.snapshot.activePalID else { return [] }
        return store.snapshot.habits(for: palID)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.greeting())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                Text(store.snapshot.activePal?.displayName ?? "There")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            VStack(spacing: 0) {
                FlameView(streak: store.headlineStreak, lit: store.headlineStreak > 0, size: 42)
                Text("\(store.headlineStreak)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .offset(y: -6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best streak, \(store.headlineStreak) days")
        }
        .padding(.top, 8)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nothing to keep yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Start a habit, then invite a pal. The day counts when you've both checked in.")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("New habit") { editor = HabitDraft() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .cardStyle()
    }
}

struct HabitCard: View {
    @Environment(AppStore.self) private var store
    var habit: Habit
    var onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: AppRoute.habit(habit.id)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        SymbolBadge(symbol: habit.symbolName, hex: habit.colorHex)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            if let name = store.snapshot.circle(for: habit)?.name {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Spacer(minLength: 8)
                        streakCount
                    }
                    if !members.isEmpty {
                        MemberAvatars(members: members)
                    }
                    Text(store.statusLine(for: habit))
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .buttonStyle(.plain)

            Button(action: onCheckIn) {
                Text(store.youCheckedIn(habit) ? "Checked in" : "Check in")
            }
            .buttonStyle(PrimaryButtonStyle(filled: !store.youCheckedIn(habit)))
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private var members: [MemberState] {
        store.members(for: habit)
    }

    private var summary: StreakSummary {
        store.summary(for: habit)
    }

    private var streakCount: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(summary.current > 0 ? Theme.ember : Theme.muted)
                Text("\(summary.current)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            Text(summary.current == 1 ? "day" : "days")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityLabel("\(summary.current) day streak")
    }
}
