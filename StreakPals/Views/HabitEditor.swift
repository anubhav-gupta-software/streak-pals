import SwiftUI

struct HabitEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: HabitDraft
    @State private var time = Date()
    @State private var error: String?
    @State private var reminderNote: String?

    init(draft: HabitDraft) {
        _draft = State(initialValue: draft)
        var components = DateComponents()
        components.hour = draft.reminderHour
        components.minute = draft.reminderMinute
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
    }

    private var isEditing: Bool { draft.habitID != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    field
                    symbolPicker
                    colorPicker
                    circlePicker
                    reminder
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.ember)
                    }
                    if let reminderNote {
                        Text(reminderNote).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Button(isEditing ? "Save" : "Create habit", action: save)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(isEditing ? "Edit habit" : "New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            TextField("Gym, reading, water", text: $draft.title)
                .textInputAutocapitalization(.sentences)
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Palette.symbols, id: \.self) { symbol in
                    Button {
                        draft.symbolName = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(draft.symbolName == symbol ? Color.white : Theme.ink)
                            .background(
                                draft.symbolName == symbol ? Theme.ember : Theme.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.line, lineWidth: draft.symbolName == symbol ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(draft.symbolName == symbol ? .isSelected : [])
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                ForEach(Palette.habitColors, id: \.self) { hex in
                    Button {
                        draft.colorHex = hex
                    } label: {
                        Circle()
                            .fill(Theme.color(hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if draft.colorHex == hex {
                                    Circle().stroke(Theme.ink, lineWidth: 2).padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                    .accessibilityAddTraits(draft.colorHex == hex ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private var circlePicker: some View {
        let circles = store.snapshot.circles.filter { circle in
            guard let palID = store.snapshot.activePalID else { return false }
            return circle.containsCurrent(palID)
        }
        VStack(alignment: .leading, spacing: 10) {
            Text("Who's in")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            if isEditing {
                Text(circleName)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            } else if circles.isEmpty {
                Text("Just you for now. Make a circle when you want pals on it.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                Picker("Circle", selection: $draft.circleID) {
                    Text("Just me").tag(Optional<UUID>.none)
                    ForEach(circles) { circle in
                        Text(circle.name).tag(Optional(circle.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
        }
    }

    private var circleName: String {
        if let id = draft.circleID, let circle = store.snapshot.circle(id) {
            return circle.name
        }
        return "Just you"
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $draft.reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminder")
                        .foregroundStyle(Theme.ink)
                    Text("A local notification. No server, no push account.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.ember)
            if draft.reminderEnabled {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        draft.reminderHour = parts.hour ?? 20
        draft.reminderMinute = parts.minute ?? 0
        Task {
            if draft.reminderEnabled {
                let allowed = await ReminderScheduler.requestAuthorization()
                if !allowed {
                    draft.reminderEnabled = false
                    reminderNote = "Notifications are off for Streak Pals. Save again and I'll skip the reminder."
                    return
                }
            }
            do {
                try store.saveHabit(draft)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
