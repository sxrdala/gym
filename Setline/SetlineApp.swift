import SwiftUI

@main
@MainActor
struct GymBloxApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var spotify = SpotifyManager()
    @StateObject private var steps = StepTracker()
    @StateObject private var journal = Journal(store: JournalStore.applicationStore())

    var body: some Scene {
        WindowGroup {
            JournalRoot(journal: journal)
                .preferredColorScheme(.dark)
                .tint(Style.mint)
                .environmentObject(spotify)
                .environmentObject(steps)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    steps.refresh(journal: journal, active: phase == .active)
                }
                .onChange(of: journal.isOpen) { _ in steps.refresh(journal: journal, active: phase == .active) }
                .onOpenURL { spotify.handle($0) }
                .onAppear {
                    spotify.setForeground(phase == .active)
                    steps.refresh(journal: journal, active: phase == .active)
                }
                .onChange(of: phase) { phase in
                    steps.refresh(journal: journal, active: phase == .active)
                    spotify.setForeground(phase == .active)
                }
        }
    }
}

private struct JournalRoot: View {
    @ObservedObject var journal: Journal

    var body: some View {
        if journal.isOpen {
            TabView {
                NavigationStack { TodayView() }
                    .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                NavigationStack { CaloriesView() }
                    .tabItem { Label("Diet", systemImage: "flame.fill") }
                NavigationStack { MusicView() }
                    .tabItem { Label("Music", systemImage: "music.note") }
                NavigationStack { ProfileView() }
                    .tabItem { Label("Profile", systemImage: "person.fill") }
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .environmentObject(journal)
        } else {
            VStack(spacing: 14) {
                EmptyState("Journal unavailable", systemImage: "externaldrive",
                           description: journal.openingError)
                Button("Try again") { journal.open() }
            }
            .padding(18)
        }
    }
}
