import SwiftUI

@main
@MainActor
struct SetlineApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var spotify = SpotifyManager()
    @StateObject private var journal = Journal(store: JournalStore.applicationStore())

    var body: some Scene {
        WindowGroup {
            JournalRoot(journal: journal)
                .preferredColorScheme(.dark)
                .tint(Style.mint)
                .environmentObject(spotify)
                .onOpenURL { spotify.handle($0) }
                .onAppear { spotify.setForeground(phase == .active) }
                .onChange(of: phase) { phase in
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
                    .tabItem { Label("Today", systemImage: "sun.max") }
                NavigationStack { RoutinesView() }
                    .tabItem { Label("Routines", systemImage: "square.stack.3d.up") }
                NavigationStack { HistoryView() }
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
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
