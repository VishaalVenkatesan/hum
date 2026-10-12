import AppKit
import MediaPlayer

struct RemoteHandlers {
    let play: @MainActor () -> Void
    let pause: @MainActor () -> Void
    let toggle: @MainActor () -> Void
    let next: @MainActor () -> Void
    let previous: @MainActor () -> Void
    let seek: @MainActor (TimeInterval) -> Void
}

@MainActor
final class NowPlayingBridge {
    private(set) var isEnabled = false
    private var targets: [(MPRemoteCommand, Any)] = []

    func setEnabled(_ enabled: Bool, handlers: RemoteHandlers) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        enabled ? attach(handlers) : detach()
    }

    func update(title: String?, artist: String?, album: String?, nowPlaying: NowPlaying?, image: NSImage?) {
        let center = MPNowPlayingInfoCenter.default()
        guard isEnabled, let nowPlaying else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title ?? "Hum",
            MPNowPlayingInfoPropertyPlaybackRate: nowPlaying.state.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: nowPlaying.position(at: Date())
        ]
        if let artist { info[MPMediaItemPropertyArtist] = artist }
        if let album { info[MPMediaItemPropertyAlbumTitle] = album }
        if let duration = nowPlaying.duration, duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let image {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        center.nowPlayingInfo = info
        center.playbackState = nowPlaying.state.isPlaying ? .playing : .paused
    }

    private func attach(_ handlers: RemoteHandlers) {
        let center = MPRemoteCommandCenter.shared()
        bind(center.playCommand) { handlers.play() }
        bind(center.pauseCommand) { handlers.pause() }
        bind(center.togglePlayPauseCommand) { handlers.toggle() }
        bind(center.nextTrackCommand) { handlers.next() }
        bind(center.previousTrackCommand) { handlers.previous() }

        let seek = center.changePlaybackPositionCommand
        seek.isEnabled = true
        let token = seek.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            MainActor.assumeIsolated { handlers.seek(position) }
            return .success
        }
        targets.append((seek, token))
    }

    private func bind(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
        command.isEnabled = true
        let token = command.addTarget { _ in
            MainActor.assumeIsolated { action() }
            return .success
        }
        targets.append((command, token))
    }

    private func detach() {
        for (command, token) in targets {
            command.removeTarget(token)
            command.isEnabled = false
        }
        targets = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
