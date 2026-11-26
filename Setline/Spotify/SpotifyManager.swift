import Combine
import UIKit
@preconcurrency import SpotifyiOS

@MainActor
final class SpotifyManager: NSObject, ObservableObject,
    @preconcurrency SPTAppRemoteDelegate, @preconcurrency SPTAppRemotePlayerStateDelegate {
    enum State: Equatable {
        case unconfigured, disconnected, connecting, connected, offlineUnavailable
    }

    @Published private(set) var state: State = .unconfigured
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var paused = true
    @Published private(set) var launchMessage: String?
    private let redirect = URL(string: "setline://spotify-login-callback")!
    private let spotifyURL = URL(string: "spotify://")!
    private var configuration: SPTConfiguration?
    private var remote: SPTAppRemote?
    private var timeout: Task<Void, Never>?
    private var foreground = false
    private var awaitingReturn = false
    private var token: String?

    init(bundle: Bundle = .main) {
        super.init()
        if let id = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
           !id.trimmed.isEmpty, !id.contains("$(") {
            configuration = SPTConfiguration(clientID: id.trimmed, redirectURL: redirect)
            state = .disconnected
        }
    }

    func openSpotify() {
        UIApplication.shared.open(spotifyURL, options: [:]) { [weak self] opened in
            self?.launchMessage = opened ? nil : "Install Spotify on this iPhone to open it here."
        }
    }

    func authorize() {
        guard let configuration else { return }
        reset(to: .disconnected)
        guard UIApplication.shared.canOpenURL(spotifyURL) else {
            state = .offlineUnavailable
            launchMessage = "Install Spotify on this iPhone, then connect again."
            return
        }
        launchMessage = nil
        let transport = makeRemote(configuration)
        awaitingReturn = true
        state = .connecting
        startTimeout()
        let attempt = ObjectIdentifier(transport)
        transport.authorizeAndPlayURI("") { [weak self] launched in
            guard !launched else { return }
            Task { @MainActor in
                guard let self, let current = self.remote, ObjectIdentifier(current) == attempt else { return }
                self.reset(to: .offlineUnavailable)
            }
        }
    }

    func handle(_ url: URL) {
        guard awaitingReturn, url.scheme == redirect.scheme, url.host == redirect.host,
              url.path == redirect.path, let remote else { return }
        guard let value = remote.authorizationParameters(from: url)?[SPTAppRemoteAccessTokenKey],
              !value.isEmpty else { reset(to: .offlineUnavailable); return }
        token = value
        reset(to: .disconnected)
        if foreground { connect() }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        guard configuration != nil else { return }
        if awaitingReturn {
            // The Spotify consent screen may remain open for longer than the IPC timeout.
            if active { startTimeout() } else { timeout?.cancel() }
        } else if active {
            if token != nil && remote == nil { connect() }
        } else {
            reset(to: .disconnected)
        }
    }

    private func makeRemote(_ configuration: SPTConfiguration) -> SPTAppRemote {
        let transport = SPTAppRemote(configuration: configuration, logLevel: .none)
        transport.delegate = self
        remote = transport
        return transport
    }

    private func connect() {
        guard let token, let configuration else { return }
        let transport = makeRemote(configuration)
        transport.connectionParameters.accessToken = token
        state = .connecting
        startTimeout()
        transport.connect()
    }

    private func startTimeout() {
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            if self?.state == .connecting { self?.reset(to: .offlineUnavailable) }
        }
    }

    private func reset(to next: State) {
        timeout?.cancel()
        timeout = nil
        awaitingReturn = false
        remote?.delegate = nil
        remote?.playerAPI?.delegate = nil
        remote?.disconnect()
        remote = nil
        title = ""
        artist = ""
        paused = true
        state = next
    }

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        guard remote === appRemote, let player = appRemote.playerAPI else { return }
        player.delegate = self
        player.subscribe(toPlayerState: { [weak self, weak appRemote] _, error in
            guard let self, let appRemote, self.remote === appRemote else { return }
            if error != nil { self.reset(to: .offlineUnavailable) }
        })
        player.getPlayerState { [weak self, weak appRemote] result, error in
            guard let self, let appRemote, self.remote === appRemote else { return }
            if let initial = result as? SPTAppRemotePlayerState {
                self.playerStateDidChange(initial)
            } else if error != nil {
                self.reset(to: .offlineUnavailable)
            }
        }
    }

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        guard remote?.isConnected == true else { return }
        timeout?.cancel()
        title = playerState.track.name
        artist = playerState.track.artist.name
        paused = playerState.isPaused
        state = .connected
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        if remote === appRemote { reset(to: .offlineUnavailable) }
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        if remote === appRemote { reset(to: .offlineUnavailable) }
    }

    enum PlaybackCommand { case toggle, previous, next }

    func playback(_ command: PlaybackCommand) {
        guard let remote, remote.isConnected, let player = remote.playerAPI else {
            reset(to: .offlineUnavailable)
            return
        }
        let callback: SPTAppRemoteCallback = { [weak self, weak remote] _, error in
            guard let self, let remote, self.remote === remote, error != nil else { return }
            self.reset(to: .offlineUnavailable)
        }
        switch command {
        case .previous: player.skip(toPrevious: callback)
        case .next: player.skip(toNext: callback)
        case .toggle:
            if paused { player.resume(callback) } else { player.pause(callback) }
        }
    }
}
