import SwiftUI
import UIKit

struct SpotifyConfig: View {
    @EnvironmentObject private var music: SpotifyManager
    @State private var copied = false
    private let bundleID = Bundle.main.bundleIdentifier

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Client ID", value: music.configured ? "Configured" : "Missing")
            HStack {
                VStack(alignment: .leading) {
                    Text("Bundle ID").font(.caption).foregroundStyle(Style.muted)
                    Text(bundleID ?? "Unknown").font(.callout.monospaced()).textSelection(.enabled)
                }
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    UIPasteboard.general.string = bundleID
                    copied = true
                    Haptics.tap()
                }.frame(minHeight: 44).disabled(bundleID == nil)
            }
        }
    }
}

struct MusicView: View {
    @EnvironmentObject private var music: SpotifyManager
    @EnvironmentObject private var journal: Journal
    @State private var adding = false
    @State private var failure: String?

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 12) {
                Label(music.state.rawValue, systemImage: "headphones")
                    .font(.subheadline).foregroundStyle(Style.mint)
                if !music.title.isEmpty {
                    Text(music.title).font(.title2.bold())
                    Text(music.artist).foregroundStyle(Style.muted)
                }
                HStack(spacing: 18) {
                    control("Previous", "backward.end.fill", .previous)
                    control(music.paused ? "Play" : "Pause", music.paused ? "play.circle.fill" : "pause.circle.fill", .toggle)
                    control("Next", "forward.end.fill", .next)
                }.frame(maxWidth: .infinity).disabled(music.state != .connected)
                if let message = music.message { Text(message).font(.footnote).textSelection(.enabled) }
                if music.configured && music.state != .connected {
                    PrimaryButton(title: "Connect Spotify", icon: "arrow.up.right") { music.authorize() }
                        .disabled(music.state == .connecting)
                }
                Button("Open Spotify", action: music.openSpotify).frame(minHeight: 44)
            }.panel().panelRow()
            HStack {
                SectionTitle(text: "Downloaded playlists")
                IconControl(title: "Add playlist", icon: "plus") { adding = true }
            }.panelRow()
            ForEach(journal.snapshot.playlists) { playlist in
                Button { music.authorize(uri: playlist.uri) } label: {
                    Label(playlist.name, systemImage: "play.fill").frame(minHeight: 44)
                }.disabled(!music.configured).panelRow().swipeActions {
                    Button("Delete", role: .destructive) {
                        do { try journal.deletePlaylist(playlist.id) } catch { failure = error.localizedDescription }
                    }
                }
            }
            SpotifyConfig().panel().panelRow()
        }.listSurface().navigationTitle("Music").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) { PlaylistForm() }
            .reporting($failure)
    }

    private func control(_ title: String, _ symbol: String, _ command: SpotifyManager.PlaybackCommand) -> some View {
        Button { music.playback(command); Haptics.tap() } label: {
            Image(systemName: symbol).font(.system(size: command == .toggle ? 56 : 28))
                .frame(minWidth: 52, minHeight: 60)
        }.accessibilityLabel(title).buttonStyle(.borderless)
    }
}

private struct PlaylistForm: View {
    @EnvironmentObject private var journal: Journal
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var uri = ""
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Playlist name", text: $name)
                TextField("spotify:playlist:…", text: $uri).textInputAutocapitalization(.never).autocorrectionDisabled()
            }.navigationTitle("Add playlist").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do { try journal.savePlaylist(name: name, uri: uri); dismiss() }
                            catch { failure = error.localizedDescription }
                        }.disabled(name.trimmed.isEmpty || uri.trimmed.isEmpty)
                    }
                }.reporting($failure)
        }
    }
}
