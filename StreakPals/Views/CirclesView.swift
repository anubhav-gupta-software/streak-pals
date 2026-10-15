import SwiftUI
import UIKit

struct CirclesView: View {
    @Environment(AppStore.self) private var store
    @State private var creating = false
    @State private var joining = false
    @State private var circleName = ""
    @State private var inviteCode = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Circles")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                    Text("A circle is the group that shares a habit. The flame only grows when all of you check in.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if circles.isEmpty {
                        empty
                    } else {
                        ForEach(circles) { circle in
                            NavigationLink(value: AppRoute.circle(circle.id)) {
                                circleRow(circle)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("New circle") { creating = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Join with a code") { joining = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
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
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .habit(let id):
                    HabitDetailView(habitID: id)
                case .circle(let id):
                    CircleDetailView(circleID: id)
                }
            }
            .sheet(isPresented: $creating) { createSheet }
            .sheet(isPresented: $joining) { joinSheet }
        }
    }

    private var circles: [Circle] {
        guard let palID = store.snapshot.activePalID else { return [] }
        return store.snapshot.circles
            .filter { $0.containsCurrent(palID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No circles yet")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Make one and share the code, or join a pal's.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .cardStyle()
    }

    private func circleRow(_ circle: Circle) -> some View {
        let habitCount = store.snapshot.habits.filter { $0.circleID == circle.id }.count
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(circle.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(circle.currentPalIDs.count) pals · \(habitCount) \(habitCount == 1 ? "habit" : "habits")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(circle.inviteCode)
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(Theme.ember)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .cardStyle()
    }

    private var createSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name the circle")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                TextField("Morning crew", text: $circleName)
                    .textInputAutocapitalization(.words)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                if let error {
                    Text(error).font(.footnote).foregroundStyle(Theme.ember)
                }
                Button("Create") {
                    do {
                        _ = try store.createCircle(name: circleName)
                        circleName = ""
                        error = nil
                        creating = false
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(circleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("New circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { creating = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var joinSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter the 6-character code.")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                TextField("AB23CD", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title2.monospaced().weight(.bold))
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                Text("On this iPhone, add the other pal in Settings and join from their profile. Another phone needs CloudKit.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(Theme.ember)
                }
                Button(busy ? "Joining…" : "Join") {
                    Task { await join() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || InviteCode.normalize(inviteCode).count < 6)
                Spacer()
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { joining = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func join() async {
        busy = true
        defer { busy = false }
        do {
            try await store.join(code: inviteCode)
            inviteCode = ""
            error = nil
            joining = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CircleDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var circleID: UUID

    @State private var copied = false
    @State private var editor: HabitDraft?
    @State private var confirmLeave = false
    @State private var error: String?

    private var circle: Circle? { store.snapshot.circle(circleID) }

    var body: some View {
        Group {
            if let circle {
                content(circle)
            } else {
                Text("That circle is gone.")
                    .foregroundStyle(Theme.muted)
                    .screenBackground()
            }
        }
        .navigationTitle(circle?.name ?? "Circle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { draft in
            HabitEditor(draft: draft)
        }
        .confirmationDialog(leaveTitle, isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(leaveButton, role: .destructive) {
                if circle?.ownerID == store.snapshot.activePalID, (circle?.currentPalIDs.count ?? 0) <= 1 {
                    store.deleteCircle(circleID)
                } else if circle?.currentPalIDs.count == 1 {
                    store.deleteCircle(circleID)
                } else {
                    store.leaveCircle(circleID)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(leaveMessage)
        }
    }

    private var isOwner: Bool { circle?.ownerID == store.snapshot.activePalID }

    private var leaveTitle: String {
        (circle?.currentPalIDs.count ?? 0) <= 1 ? "Delete this circle?" : (isOwner ? "Leave this circle?" : "Leave this circle?")
    }

    private var leaveButton: String {
        (circle?.currentPalIDs.count ?? 0) <= 1 ? "Delete circle" : "Leave"
    }

    private var leaveMessage: String {
        (circle?.currentPalIDs.count ?? 0) <= 1
            ? "You're the last pal. The circle and its habits will go."
            : "You won't be required on future days. Past days stay as they were."
    }

    private func content(_ circle: Circle) -> some View {
        let habits = store.snapshot.habits.filter { $0.circleID == circle.id }.sorted { $0.createdAt < $1.createdAt }
        let locals = store.snapshot.pals.filter { $0.isLocalProfile && !circle.containsCurrent($0.id) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite code")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(spaced(circle.inviteCode))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .tracking(2)
                    Button(copied ? "Copied" : "Copy code") {
                        UIPasteboard.general.string = circle.inviteCode
                        copied = true
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                    Text("Pals on this iPhone can join with the code. Syncing it to another phone needs CloudKit.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Pals")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    ForEach(circle.currentPalIDs, id: \.self) { palID in
                        let pal = store.snapshot.pal(palID)
                        HStack(spacing: 12) {
                            Text(pal?.initial ?? "?")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.color(pal?.colorHex ?? "8C6B5E"))
                                .frame(width: 36, height: 36)
                                .background(Theme.color(pal?.colorHex ?? "8C6B5E").opacity(0.16), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pal?.displayName ?? "Pal")
                                    .foregroundStyle(Theme.ink)
                                if palID == store.snapshot.activePalID {
                                    Text("You")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                } else if palID == circle.ownerID {
                                    Text("Started the circle")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            Spacer()
                        }
                    }
                    ForEach(locals) { pal in
                        Button("Add \(pal.displayName)") {
                            do {
                                try store.addPal(pal.id, to: circle.id)
                                error = nil
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.ember)
                    }
                }
                .padding(16)
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Habits")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if habits.isEmpty {
                        Text("No shared habits yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(habits) { habit in
                        NavigationLink(value: AppRoute.habit(habit.id)) {
                            HStack(spacing: 12) {
                                SymbolBadge(symbol: habit.symbolName, hex: habit.colorHex, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.title)
                                        .foregroundStyle(Theme.ink)
                                    Text("\(store.summary(for: habit).current) day streak")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Add a habit") {
                        var draft = HabitDraft()
                        draft.circleID = circle.id
                        editor = draft
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
                .cardStyle()

                Button(leaveButton, role: .destructive) {
                    confirmLeave = true
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .screenBackground()
    }

    private func spaced(_ code: String) -> String {
        code.map(String.init).joined(separator: " ")
    }
}
