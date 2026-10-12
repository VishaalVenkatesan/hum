import Foundation
import Observation

@MainActor
@Observable
final class SpeakerStore {
    private(set) var groups: [SonosGroup] = []
    private(set) var volumes: [String: VolumeState] = [:]
    private(set) var nowPlaying: [String: NowPlaying] = [:]
    private(set) var isDiscovering = false
    private(set) var issue: DiscoveryIssue?
    private(set) var sound: [String: SoundSettings] = [:]
    private(set) var speakerInfo: [String: SpeakerInfo] = [:]
    var selectedGroupID: String?

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var localEditUntil: [String: Date] = [:]
    @ObservationIgnored private var lastDiscovery: Date?

    private static let knownHostsKey = "knownHosts"
    private static let pollInterval: Duration = .seconds(3)
    private static let rediscoveryInterval: TimeInterval = 60

    var allMembers: [SonosMember] { groups.flatMap(\.members) }

    var averageVolume: Int { averageLevel(of: allMembers) }

    var anyPlaying: Bool { nowPlaying.values.contains { $0.state.isPlaying } }

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func rediscover() async {
        lastDiscovery = nil
        await tick()
    }

    private func tick() async {
        if groups.isEmpty || lastDiscovery.map({ Date().timeIntervalSince($0) > Self.rediscoveryInterval }) ?? true {
            await discover()
        }
        await refreshStates()
    }

    private func discover() async {
        isDiscovering = true
        defer { isDiscovering = false }

        let result = await SSDPDiscovery.discover()
        let candidates = result.hosts.union(knownHosts)
        guard !candidates.isEmpty else {
            issue = result.isBlocked ? .localNetworkBlocked : .noSpeakers
            return
        }

        for host in candidates.sorted() {
            guard let topology = try? await SonosController(host: host).topology(), !topology.isEmpty else { continue }
            groups = topology
            knownHosts = Set(topology.flatMap(\.members).map(\.host))
            lastDiscovery = Date()
            issue = nil
            return
        }
        issue = result.isBlocked ? .localNetworkBlocked : .unreachable
    }

    func refreshStates() async {
        let snapshot = groups
        await withTaskGroup(of: Void.self) { taskGroup in
            for group in snapshot {
                taskGroup.addTask { [weak self] in
                    guard let state = try? await SonosController(host: group.coordinator.host).nowPlaying() else { return }
                    await self?.apply(nowPlaying: state, for: group.id)
                }
                for member in group.members {
                    taskGroup.addTask { [weak self] in
                        guard let volume = try? await SonosController(host: member.host).volume() else { return }
                        await self?.apply(volume: volume, for: member.id)
                    }
                }
            }
        }
    }

    private func apply(nowPlaying state: NowPlaying, for groupID: String) {
        if nowPlaying[groupID] != state { nowPlaying[groupID] = state }
    }

    private func apply(volume: VolumeState, for memberID: String) {
        if let until = localEditUntil[memberID], until > Date() { return }
        if volumes[memberID] != volume { volumes[memberID] = volume }
    }

    func setVolume(_ level: Int, for member: SonosMember) {
        let clamped = min(max(level, 0), 100)
        volumes[member.id] = VolumeState(level: clamped, muted: volumes[member.id]?.muted ?? false)
        localEditUntil[member.id] = Date().addingTimeInterval(2)
        debounce("volume-\(member.id)") { try await SonosController(host: member.host).setVolume(clamped) }
    }

    func loadSound(for member: SonosMember) async {
        guard let settings = try? await SonosController(host: member.host).soundSettings() else { return }
        sound[member.id] = settings
    }

    func setBass(_ level: Int, for member: SonosMember) {
        sound[member.id]?.bass = level
        debounce("bass-\(member.id)") { try await SonosController(host: member.host).setBass(level) }
    }

    func setTreble(_ level: Int, for member: SonosMember) {
        sound[member.id]?.treble = level
        debounce("treble-\(member.id)") { try await SonosController(host: member.host).setTreble(level) }
    }

    func setLoudness(_ enabled: Bool, for member: SonosMember) {
        sound[member.id]?.loudness = enabled
        debounce("loudness-\(member.id)") { try await SonosController(host: member.host).setLoudness(enabled) }
    }

    func resetSound(for member: SonosMember) {
        setBass(SoundSettings.flat.bass, for: member)
        setTreble(SoundSettings.flat.treble, for: member)
        setLoudness(SoundSettings.flat.loudness, for: member)
    }

    func setPlayMode(_ mode: PlayMode, for group: SonosGroup) {
        nowPlaying[group.id]?.playMode = mode
        perform(on: group) { try await $0.setPlayMode(mode) }
    }

    func setCrossfade(_ enabled: Bool, for group: SonosGroup) {
        nowPlaying[group.id]?.crossfade = enabled
        perform(on: group) { try await $0.setCrossfade(enabled) }
    }

    func configureSleepTimer(_ duration: TimeInterval?, for groups: [SonosGroup]) {
        for group in groups {
            nowPlaying[group.id]?.sleepTimerEnd = duration.map { Date().addingTimeInterval($0) }
            perform(on: group) { try await $0.configureSleepTimer(duration) }
        }
    }

    func loadSpeakerInfo(for member: SonosMember) async {
        guard let info = try? await SonosController(host: member.host).speakerInfo() else { return }
        speakerInfo[member.id] = info
    }

    func setStatusLight(_ on: Bool, for member: SonosMember) {
        speakerInfo[member.id]?.statusLight = on
        Task { try? await SonosController(host: member.host).setStatusLight(on) }
    }

    func setButtonsLocked(_ locked: Bool, for member: SonosMember) {
        speakerInfo[member.id]?.buttonsLocked = locked
        Task { try? await SonosController(host: member.host).setButtonsLocked(locked) }
    }

    private func debounce(_ key: String, _ action: @escaping @Sendable () async throws -> Void) {
        debounceTasks[key]?.cancel()
        debounceTasks[key] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await action()
        }
    }

    func setVolume(_ target: Int, across members: [SonosMember]) {
        let current = averageLevel(of: members)
        let desired = min(max(target, 0), 100)
        let delta = desired - current
        guard delta != 0 else { return }
        for member in members {
            let level = volumes[member.id]?.level ?? current
            let next: Int
            if desired < 1 {
                next = 0
            } else if delta > 0 || current == 0 {
                next = level + delta
            } else {
                next = Int((Double(level) / Double(current) * Double(desired)).rounded(.up))
            }
            setVolume(next, for: member)
        }
    }

    func groupVolume(_ group: SonosGroup) -> Int {
        averageLevel(of: group.members)
    }

    private func averageLevel(of members: [SonosMember]) -> Int {
        let levels = members.compactMap { volumes[$0.id]?.level }
        guard !levels.isEmpty else { return 0 }
        return Int((Double(levels.reduce(0, +)) / Double(levels.count)).rounded())
    }

    func toggleMute(_ member: SonosMember) {
        let muted = !(volumes[member.id]?.muted ?? false)
        volumes[member.id]?.muted = muted
        localEditUntil[member.id] = Date().addingTimeInterval(2)
        Task { try? await SonosController(host: member.host).setMute(muted) }
    }

    func muteAll(_ muted: Bool) {
        for member in allMembers where volumes[member.id]?.muted != muted {
            toggleMute(member)
        }
    }

    func togglePlayback(_ group: SonosGroup) {
        let playing = nowPlaying[group.id]?.state.isPlaying ?? false
        nowPlaying[group.id]?.state = playing ? .paused : .playing
        perform(on: group) { playing ? try await $0.pause() : try await $0.play() }
    }

    func pauseAll() {
        for group in groups where nowPlaying[group.id]?.state.isPlaying == true {
            togglePlayback(group)
        }
    }

    func next(_ group: SonosGroup) {
        perform(on: group) { try await $0.next() }
    }

    func previous(_ group: SonosGroup) {
        perform(on: group) { try await $0.previous() }
    }

    func seek(_ group: SonosGroup, to seconds: TimeInterval) {
        nowPlaying[group.id]?.elapsed = seconds
        nowPlaying[group.id]?.sampledAt = Date()
        perform(on: group) { try await $0.seek(to: seconds) }
    }

    func join(_ member: SonosMember, to group: SonosGroup) {
        Task {
            try? await SonosController(host: member.host).join(coordinatorID: group.coordinator.id)
            await rediscover()
        }
    }

    func ungroup(_ member: SonosMember) {
        Task {
            try? await SonosController(host: member.host).leaveGroup()
            await rediscover()
        }
    }

    func perform(on group: SonosGroup, _ action: @escaping @Sendable (SonosController) async throws -> Void) {
        Task {
            try? await action(SonosController(host: group.coordinator.host))
            try? await Task.sleep(for: .milliseconds(400))
            await refreshStates()
        }
    }

    private var knownHosts: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.knownHostsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.knownHostsKey) }
    }
}
