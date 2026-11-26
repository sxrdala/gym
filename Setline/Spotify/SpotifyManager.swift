import Combine
import UIKit
@preconcurrency import SpotifyiOS

@MainActor
final class SpotifyManager: NSObject, ObservableObject,
    @preconcurrency SPTAppRemoteDelegate, @preconcurrency SPTAppRemotePlayerStateDelegate {
    enum State: String {
        case unconfigured = "Client ID missing"
        case disconnected = "Disconnected"
        case authorizing = "Authorizing"
        case connecting = "Connecting"
        case connected = "Connected"
    }

    @Published private(set) var state: State = .unconfigured
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var paused = true
    @Published private(set) var message: String?
    private let redirect = URL(string: "gymblox://spotify-login-callback")!
    private let spotifyURL = URL(string: "spotify://")!
    private var configuration: SPTConfiguration?
    private var remote: SPTAppRemote?
    private var foreground = false
    private var token: String?
    var configured: Bool { configuration != nil }

    init(bundle: Bundle = .main) {
        super.init()
        if let id = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
           !id.trimmed.isEmpty, !id.contains("$(") {
            configuration = SPTConfiguration(clientID: id, redirectURL: redirect)
            state = .disconnected
        }
    }

    func openSpotify() {
        UIApplication.shared.open(spotifyURL, options: [:]) { [weak self] opened in
            if !opened { self?.message = "Install Spotify." }
        }
    }

    func authorize(uri: String = "") {
        guard configured else { return }
        disconnect()
        token = nil
        message = nil
        guard UIApplication.shared.canOpenURL(spotifyURL), let appRemote = transport() else {
            message = "Install Spotify."
            return
        }
        state = .authorizing
        appRemote.authorizeAndPlayURI(uri) { [weak self, weak appRemote] launched in
            Task { @MainActor in
                guard let self, let appRemote, self.remote === appRemote,
                      self.state == .authorizing, !launched else { return }
                self.fail("Spotify didn’t open.")
            }
        }
    }

    func handle(_ url: URL) {
        guard url.scheme == redirect.scheme, url.host == redirect.host, url.path == redirect.path,
              let appRemote = transport() else { return }
        let parameters = appRemote.authorizationParameters(from: url)
        if let error = parameters?[SPTAppRemoteErrorDescriptionKey] {
            token = nil
            fail(error)
        } else if let value = parameters?[SPTAppRemoteAccessTokenKey], !value.isEmpty {
            token = value
            appRemote.connectionParameters.accessToken = value
            message = nil
            state = .disconnected
            if foreground { connect() }
        } else {
            token = nil
            fail("Missing access token.")
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        guard configured else { return }
        if active {
            connect()
            // Cancelling in Spotify may return without a callback. Allow another handoff.
            if state == .authorizing { state = .disconnected }
        } else if state != .authorizing {
            disconnect()
        }
    }

    private func transport() -> SPTAppRemote? {
        if let remote { return remote }
        guard let configuration else { return nil }
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .none)
        appRemote.delegate = self
        remote = appRemote
        return appRemote
    }

    private func connect() {
        guard foreground, let token, state != .connecting, let appRemote = transport(),
              !appRemote.isConnected else { return }
        appRemote.connectionParameters.accessToken = token
        state = .connecting
        appRemote.connect()
    }

    private func disconnect() {
        remote?.delegate = nil
        remote?.playerAPI?.delegate = nil
        remote?.disconnect()
        remote = nil
        title = ""
        artist = ""
        paused = true
        state = .disconnected
    }

    private func fail(_ description: String) {
        disconnect()
        message = description
    }

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        guard remote === appRemote, let player = appRemote.playerAPI else { return }
        message = nil
        state = .connected
        player.delegate = self
        player.subscribe(toPlayerState: { [weak self, weak appRemote] _, error in
            guard let self, let appRemote, self.remote === appRemote, let error else { return }
            self.message = error.localizedDescription
        })
        player.getPlayerState { [weak self, weak appRemote] result, error in
            guard let self, let appRemote, self.remote === appRemote else { return }
            if let initial = result as? SPTAppRemotePlayerState { self.playerStateDidChange(initial) }
            else if let error { self.message = error.localizedDescription }
        }
    }

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        guard remote?.isConnected == true else { return }
        title = playerState.track.name
        artist = playerState.track.artist.name
        paused = playerState.isPaused
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        if remote === appRemote { fail(error?.localizedDescription ?? "Connection failed.") }
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        if remote === appRemote { disconnect(); message = error?.localizedDescription }
    }

    enum PlaybackCommand { case toggle, previous, next }

    func playback(_ command: PlaybackCommand) {
        guard let remote, remote.isConnected, let player = remote.playerAPI else { return }
        let callback: SPTAppRemoteCallback = { [weak self, weak remote] _, error in
            guard let self, let remote, self.remote === remote, let error else { return }
            self.message = error.localizedDescription
        }
        switch command {
        case .previous: player.skip(toPrevious: callback)
        case .next: player.skip(toNext: callback)
        case .toggle:
            if paused { player.resume(callback) } else { player.pause(callback) }
        }
    }
}
