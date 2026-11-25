import SwiftUI

struct SpotifyBar: View {
    @EnvironmentObject private var music
    @State private var setup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                IconControl(title: "Spotify Setup", icon: "headphones") { setup = true }
                if music.state == .connected {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.title).font(.subheadline.weight(.semibold))
                        Text(music.artist).font(.caption).foregroundStyle(Style.muted)
                    }.lineLimit(1)
                    Spacer(minLength: 0)
                    IconControl(title: music.paused ? "Play" : "Pause",
                                icon: music.paused ? "play.fill" : "pause.fill") { music.playback() }
                    IconControl(title: "Next track", icon: "forward.end.fill") { music.playback(next: true) }
                } else {
                    if music.state == .connecting { ProgressView().controlSize(.small) }
                    Spacer(minLength: 0)
                    Button(action: music.openSpotify) {
                        Label("Open Spotify", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                            .accessibilityLabel("Open Spotify")
                    }.buttonStyle(.plain)
                }
            }
            if let message = music.launchMessage {
                Text(message).font(.caption).foregroundStyle(Style.muted)
            }
        }.padding(.horizontal, 10).padding(.vertical, 2)
            .background(Style.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(Style.motion, value: music.state)
            .sheet(isPresented: $setup) { SpotifySetup() }
    }
}

struct SpotifySetup: View {
    @EnvironmentObject private var music
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    instruction("Connect while online", "Sign in to Spotify on this iPhone. Tap Connect Spotify below and approve access. Spotify may resume playback.")
                    instruction("Download your playlist", "In Spotify, open the playlist and turn on Download. Wait for the download to finish before switching to Airplane Mode.")
                    instruction("Play between sets", "Start your playlist in Spotify. Return to your workout to pause, resume, or skip a track.")
                    if music.state == .connected {
                        Label("Connected to Spotify", systemImage: "checkmark.circle").foregroundStyle(Style.mint)
                    } else if music.state == .unconfigured {
                        Text("This build needs a Spotify client ID to enable playback controls. You can still open Spotify.")
                            .font(.subheadline).foregroundStyle(Style.muted)
                    } else {
                        if music.state == .offlineUnavailable {
                            Text("Spotify is unavailable. Open Spotify to start your playlist, then reconnect.")
                                .font(.subheadline).foregroundStyle(Style.muted)
                        }
                        PrimaryButton(title: music.state == .connecting ? "Connecting…" : "Connect Spotify",
                                      icon: "arrow.up.right", action: music.authorize)
                            .disabled(music.state == .connecting)
                    }
                    Button(action: music.openSpotify) {
                        Label("Open Spotify", systemImage: "arrow.up.right").frame(minHeight: 44)
                    }
                    if let message = music.launchMessage { Text(message).font(.footnote).foregroundStyle(Style.muted) }
                }.padding(18)
            }
            .navigationTitle("Spotify Setup").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func instruction(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(Style.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
