import SwiftUI

struct HabitDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var habitID: UUID

    @State private var editor: HabitDraft?
    @State private var checkIn = false
    @State private var confirmDelete = false
    @State private var photoPreview: PreviewPhoto?

    private var habit: Habit? { store.snapshot.habit(habitID) }

    var body: some View {
        Group {
            if let habit {
                content(habit)
            } else {
                Text("That habit is gone.")
                    .foregroundStyle(Theme.muted)
                    .screenBackground()
            }
        }
        .navigationTitle(habit?.title ?? "Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if habit != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit") { editor = draft(from: habit) }
                        Button("Delete", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Habit actions")
                }
            }
        }
        .sheet(item: $editor) { draft in
            HabitEditor(draft: draft)
        }
        .sheet(isPresented: $checkIn) {
            CheckInSheet(habitID: habitID)
        }
        .sheet(item: $photoPreview) { item in
            PhotoPreview(data: item.data)
        }
        .confirmationDialog("Delete this habit?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete habit", role: .destructive) {
                store.deleteHabit(habitID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Check-ins for it go too.")
        }
    }

    private func content(_ habit: Habit) -> some View {
        let summary = store.summary(for: habit)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 8) {
                    FlameView(streak: summary.current, lit: summary.current > 0, size: 86)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.current)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        Text(summary.current == 1 ? "day" : "days")
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                        Text("Longest \(summary.longest)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.current) day streak. Longest \(summary.longest).")

                Text(store.statusLine(for: habit))
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("This week")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    DayStrip(days: store.recentDays(for: habit))
                }
                .padding(16)
                .cardStyle()

                if !store.members(for: habit).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        ForEach(store.members(for: habit)) { member in
                            HStack(spacing: 12) {
                                Text(member.pal.initial)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.color(member.pal.colorHex))
                                    .frame(width: 36, height: 36)
                                    .background(Theme.color(member.pal.colorHex).opacity(0.16), in: Circle())
                                Text(member.pal.displayName)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: member.checkedIn ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(member.checkedIn ? Theme.good : Theme.muted)
                                    .accessibilityLabel(member.checkedIn ? "Checked in" : "Not yet")
                            }
                        }
                    }
                    .padding(16)
                    .cardStyle()
                }

                history(habit)

                Button(store.youCheckedIn(habit) ? "Update check-in" : "Check in") {
                    checkIn = true
                }
                .buttonStyle(PrimaryButtonStyle(filled: !store.youCheckedIn(habit)))
            }
            .padding(20)
        }
        .screenBackground()
    }

    @ViewBuilder
    private func history(_ habit: Habit) -> some View {
        let items = store.snapshot.checkIns
            .filter { $0.habitID == habit.id }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent check-ins")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                ForEach(Array(items)) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.snapshot.pal(item.palID)?.displayName ?? "Pal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(item.dayKey)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.muted)
                        }
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink.opacity(0.85))
                        }
                        if let filename = item.photoFilename,
                           let data = store.photoData(filename: filename),
                           let image = UIImage(data: data) {
                            Button {
                                photoPreview = PreviewPhoto(data: data)
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo proof")
                        }
                    }
                    .padding(.vertical, 4)
                    if item.id != items.last?.id {
                        Divider().overlay(Theme.line)
                    }
                }
            }
            .padding(16)
            .cardStyle()
        }
    }

    private func draft(from habit: Habit?) -> HabitDraft {
        guard let habit else { return HabitDraft() }
        var draft = HabitDraft()
        draft.habitID = habit.id
        draft.title = habit.title
        draft.symbolName = habit.symbolName
        draft.colorHex = habit.colorHex
        draft.circleID = habit.circleID
        draft.reminderEnabled = habit.reminderEnabled
        draft.reminderHour = habit.reminderHour
        draft.reminderMinute = habit.reminderMinute
        return draft
    }
}

struct PreviewPhoto: Identifiable {
    var id = UUID()
    var data: Data
}

struct PhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    var data: Data

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("Couldn't open that photo.")
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
