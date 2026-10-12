import Carbon.HIToolbox
import Observation

@MainActor
@Observable
final class AppController {
    let store = SpeakerStore()
    let artwork = ArtworkLoader()
    let sleepTimer = SleepTimer()
    let lyrics = LyricsService()
    let callMonitor = CallMonitor()

    @ObservationIgnored private let hud = HUDController()
    @ObservationIgnored private let nowPlayingBridge = NowPlayingBridge()
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var callSnapshot: CallSnapshot?
    @ObservationIgnored private var callEndTask: Task<Void, Never>?

    private enum CallSnapshot {
        case lowered([SonosMember: Int])
        case paused([SonosGroup])
    }

    private static let volumeStep = 4
    private static let duckFraction = 0.25

    func start() {
        guard !didStart else { return }
        didStart = true
        store.startPolling()
        callMonitor.start()
    }

    func setHotKeys(enabled: Bool) {
        if enabled {
            HotKeyCenter.shared.register(hotKeys)
        } else {
            HotKeyCenter.shared.unregisterAll()
        }
    }

    func setMediaKeys(enabled: Bool) {
        nowPlayingBridge.setEnabled(enabled, handlers: RemoteHandlers(
            play: { [weak self] in self?.setPlaying(true) },
            pause: { [weak self] in self?.setPlaying(false) },
            toggle: { [weak self] in self?.togglePlayback() },
            next: { [weak self] in self?.skip(forward: true) },
            previous: { [weak self] in self?.skip(forward: false) },
            seek: { [weak self] position in
                guard let self, let group = store.heroGroup else { return }
                store.seek(group, to: position)
            }
        ))
        Task { await syncNowPlaying() }
    }

    func syncNowPlaying() async {
        guard nowPlayingBridge.isEnabled else { return }
        let group = store.heroGroup
        let nowPlaying = group.flatMap { store.nowPlaying[$0.id] }
        if let url = nowPlaying?.artURL {
            await artwork.load(url)
        }
        nowPlayingBridge.update(
            title: nowPlaying?.title ?? group?.name,
            artist: nowPlaying?.artist ?? group.map { "on \($0.name)" },
            album: nowPlaying?.album,
            nowPlaying: nowPlaying,
            image: artwork.artwork(for: nowPlaying?.artURL)?.image
        )
    }

    func handleCall(active: Bool, behavior: CallBehavior) {
        callEndTask?.cancel()
        if active {
            guard callSnapshot == nil, behavior != .off, store.anyPlaying else { return }
            switch behavior {
            case .lower:
                callSnapshot = .lowered(store.duckPlaying(to: Self.duckFraction))
                hud.show(symbol: "phone.fill", title: "On a call — music lowered")
            case .pause:
                callSnapshot = .paused(store.pausePlaying())
                hud.show(symbol: "phone.fill", title: "On a call — music paused")
            case .off:
                break
            }
            return
        }

        guard let snapshot = callSnapshot else { return }
        callEndTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            switch snapshot {
            case .lowered(let originals): store.restoreVolumes(originals)
            case .paused(let groups): store.resume(groups)
            }
            callSnapshot = nil
            hud.show(symbol: "music.note", title: "Call ended — welcome back")
        }
    }

    var hotKeys: [HotKey] {
        [
            HotKey(keyCode: kVK_UpArrow, label: "Volume up") { [weak self] in self?.nudgeVolume(by: Self.volumeStep) },
            HotKey(keyCode: kVK_DownArrow, label: "Volume down") { [weak self] in self?.nudgeVolume(by: -Self.volumeStep) },
            HotKey(keyCode: kVK_Space, label: "Play / pause") { [weak self] in self?.togglePlayback() },
            HotKey(keyCode: kVK_RightArrow, label: "Next track") { [weak self] in self?.skip(forward: true) },
            HotKey(keyCode: kVK_LeftArrow, label: "Previous track") { [weak self] in self?.skip(forward: false) },
            HotKey(keyCode: kVK_ANSI_M, label: "Mute all") { [weak self] in self?.toggleMuteAll() }
        ]
    }

    private func nudgeVolume(by delta: Int) {
        guard !store.allMembers.isEmpty else { return }
        let level = store.nudgeAllVolume(by: delta)
        hud.show(symbol: Self.volumeSymbol(for: level), level: level)
    }

    private func setPlaying(_ playing: Bool) {
        guard let group = store.heroGroup, store.isPlaying(group) != playing else { return }
        store.togglePlayback(group)
    }

    private func togglePlayback() {
        guard let group = store.heroGroup else { return }
        let wasPlaying = store.isPlaying(group)
        store.togglePlayback(group)
        hud.show(symbol: wasPlaying ? "pause.fill" : "play.fill", title: store.nowPlaying[group.id]?.headline ?? group.name)
    }

    private func skip(forward: Bool) {
        guard let group = store.heroGroup else { return }
        forward ? store.next(group) : store.previous(group)
        hud.show(symbol: forward ? "forward.fill" : "backward.fill", title: group.name)
    }

    private func toggleMuteAll() {
        let members = store.allMembers
        guard !members.isEmpty else { return }
        let mute = !store.isMuted(members)
        store.setMuted(mute, members: members)
        hud.show(symbol: mute ? "speaker.slash.fill" : Self.volumeSymbol(for: store.averageVolume), level: mute ? 0 : store.averageVolume)
    }

    static func volumeSymbol(for level: Int) -> String {
        switch level {
        case 0: "speaker.slash.fill"
        case 1..<34: "speaker.wave.1.fill"
        case 34..<67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
