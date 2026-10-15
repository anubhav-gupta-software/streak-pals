import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        Group {
            if store.snapshot.activePal == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .tint(Theme.ember)
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
        }
        .sheet(item: $store.pendingCheckIn) { box in
            CheckInSheet(habitID: box.id)
        }
        .overlay {
            if let title = store.celebrationText {
                CelebrationCover(habitTitle: title)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .task(id: store.celebrationID) {
                        let token = store.celebrationID
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled, store.celebrationID == token else { return }
                        store.celebrationText = nil
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: store.celebrationText)
        .sensoryFeedback(.success, trigger: store.celebrationID)
        .onOpenURL { store.open($0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reloadFromDisk()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            CirclesView()
                .tabItem { Label("Circles", systemImage: "person.2.fill") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
    }
}

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 12)
            HStack {
                FlameView(streak: 1, size: 92)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Streak Pals")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("A streak stays lit only when every pal checks in that day.")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                TextField("Alex", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focused)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
                    .onSubmit(start)
            }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.ember)
            }
            Button("Start", action: start)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding(.horizontal, 24)
        .screenBackground()
        .onAppear { focused = true }
    }

    private func start() {
        do {
            try store.createProfile(name: name)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
