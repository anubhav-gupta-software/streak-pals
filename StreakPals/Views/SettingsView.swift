import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var addingPal = false
    @State private var palName = ""
    @State private var error: String?
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameSection
                    palsSection
                    reminderSection
                    syncSection
                    Button("How streaks work") { showRules = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                    about
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                name = store.snapshot.activePal?.displayName ?? ""
            }
            .sheet(isPresented: $showRules) {
                RulesView()
            }
            .alert("Add a pal on this iPhone", isPresented: $addingPal) {
                TextField("Name", text: $palName)
                Button("Add") { addPal() }
                Button("Cancel", role: .cancel) { palName = "" }
            } message: {
                Text("They get their own profile on this phone. Switch to them to check in, or add them to a circle.")
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
            Button("Save name") {
                store.renameActivePal(name)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var palsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pals on this iPhone")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Handy when you share a phone, and the way to try a circle without a second device.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(store.snapshot.pals.filter(\.isLocalProfile)) { pal in
                Button {
                    store.switchToPal(pal.id)
                    name = pal.displayName
                } label: {
                    HStack(spacing: 12) {
                        Text(pal.initial)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.color(pal.colorHex))
                            .frame(width: 36, height: 36)
                            .background(Theme.color(pal.colorHex).opacity(0.16), in: Circle())
                        Text(pal.displayName)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if pal.id == store.snapshot.activePalID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.ember)
                                .accessibilityLabel("Active")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.ember)
            }
            Button("Add a pal") {
                palName = ""
                addingPal = true
            }
            .buttonStyle(PrimaryButtonStyle(filled: false))
        }
        .padding(16)
        .cardStyle()
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: remindersBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders")
                        .foregroundStyle(Theme.ink)
                    Text("Follows whichever pal you're using. These are local notifications.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.ember)
        }
        .padding(16)
        .cardStyle()
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { store.snapshot.remindersEnabled },
            set: { enabled in
                Task {
                    if enabled {
                        let allowed = await ReminderScheduler.requestAuthorization()
                        store.setRemindersEnabled(allowed)
                    } else {
                        store.setRemindersEnabled(false)
                    }
                }
            }
        )
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(store.backend == .cloudKit ? "CloudKit" : "On this iPhone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(syncCopy)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Label(store.usesAppGroup ? "App Group is on" : "App Group is off", systemImage: store.usesAppGroup ? "checkmark.circle.fill" : "iphone")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(store.usesAppGroup ? Theme.good : Theme.muted)
            if let last = store.lastSyncedAt {
                Text("Last sync \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            if let lastSyncError = store.lastSyncError {
                Text(lastSyncError)
                    .font(.caption)
                    .foregroundStyle(Theme.ember)
            }
            if store.backend == .cloudKit {
                Button(store.syncing ? "Syncing…" : "Sync now") {
                    Task { await store.refresh() }
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
                .disabled(store.syncing)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var syncCopy: String {
        if store.backend == .cloudKit {
            return "Circles, habits, and check-ins sync through the CloudKit container in the project. Photos go with them."
        }
        return "Nothing leaves this iPhone. Invite codes work for pals you add here. CloudKit is in the app, switched off, and needs a paid Apple Developer account to turn on."
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Streak Pals \(version)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text("Habits are yours. A shared one only keeps its streak when every pal shows up.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 4)
    }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func addPal() {
        do {
            try store.addLocalPal(name: palName)
            palName = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FlameView(streak: 4, size: 72)
                    Text("The day isn't over until everyone has checked in.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    rule("A personal habit only needs you.")
                    rule("A circle habit needs every pal who was in the circle that day.")
                    rule("If today is still open, the streak stays up and shows who you're waiting on.")
                    rule("If yesterday was missed, the count starts over the next time you all make it.")
                    rule("Someone who joins today isn't required for the days before they arrived.")
                    rule("Leaving stops the requirement from that day on. Older days stay put.")
                }
                .padding(24)
            }
            .screenBackground()
            .navigationTitle("Streaks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.ember)
                .padding(.top, 2)
            Text(text)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
