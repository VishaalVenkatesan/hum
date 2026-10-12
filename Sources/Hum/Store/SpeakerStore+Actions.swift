import Foundation

extension SpeakerStore {
    var primaryGroup: SonosGroup? {
        groups.first { nowPlaying[$0.id]?.state.isPlaying == true } ?? groups.first
    }

    var heroGroup: SonosGroup? {
        groups.first { $0.id == selectedGroupID } ?? primaryGroup
    }

    var canGroupAll: Bool { groups.count > 1 }

    var hasGroupedRooms: Bool { groups.contains { $0.members.count > 1 } }

    func isPlaying(_ group: SonosGroup) -> Bool {
        nowPlaying[group.id]?.state.isPlaying == true
    }

    func isMuted(_ members: [SonosMember]) -> Bool {
        !members.isEmpty && members.allSatisfy { volumes[$0.id]?.muted == true }
    }

    func setMuted(_ muted: Bool, members: [SonosMember]) {
        for member in members where volumes[member.id]?.muted != muted {
            toggleMute(member)
        }
    }

    func nudgeAllVolume(by delta: Int) -> Int {
        let target = min(max(averageVolume + delta, 0), 100)
        setVolume(target, across: allMembers)
        return target
    }

    func groupAll() async {
        guard canGroupAll, let host = primaryGroup else { return }
        for group in groups where group.id != host.id {
            let ordered = group.members.filter { $0.id != group.coordinator.id } + [group.coordinator]
            for member in ordered {
                try? await SonosController(host: member.host).join(coordinatorID: host.coordinator.id)
            }
        }
        await rediscover()
    }

    func ungroupAll() async {
        for group in groups {
            for member in group.members where member.id != group.coordinator.id {
                try? await SonosController(host: member.host).leaveGroup()
            }
        }
        await rediscover()
    }

    func moveMusic(from source: SonosGroup, to target: SonosGroup) async {
        for member in target.members {
            try? await SonosController(host: member.host).join(coordinatorID: source.coordinator.id)
        }
        try? await Task.sleep(for: .seconds(1))
        try? await SonosController(host: source.coordinator.host).delegateCoordination(to: target.coordinator.id)
        try? await Task.sleep(for: .milliseconds(500))
        for member in source.members where member.id != source.coordinator.id {
            try? await SonosController(host: member.host).leaveGroup()
        }
        selectedGroupID = nil
        await rediscover()
    }

    func duckPlaying(to fraction: Double) -> [SonosMember: Int] {
        let members = groups.filter(isPlaying).flatMap(\.members)
        var originals: [SonosMember: Int] = [:]
        for member in members {
            let level = volumes[member.id]?.level ?? 0
            originals[member] = level
            setVolume(Int((Double(level) * fraction).rounded()), for: member)
        }
        return originals
    }

    func restoreVolumes(_ originals: [SonosMember: Int]) {
        for (member, level) in originals {
            setVolume(level, for: member)
        }
    }

    func pausePlaying() -> [SonosGroup] {
        let playing = groups.filter(isPlaying)
        playing.forEach(togglePlayback)
        return playing
    }

    func resume(_ paused: [SonosGroup]) {
        for group in paused {
            perform(on: group) { try await $0.play() }
        }
    }

    func fadeOutAndPause(over duration: TimeInterval, steps: Int = 20) async {
        let playing = groups.filter(isPlaying)
        let members = playing.flatMap(\.members)
        let originals = Dictionary(uniqueKeysWithValues: members.map { ($0.id, volumes[$0.id]?.level ?? 0) })
        guard !members.isEmpty else { return }

        for step in 1...steps {
            if Task.isCancelled { break }
            let factor = 1 - Double(step) / Double(steps)
            for member in members {
                setVolume(Int((Double(originals[member.id] ?? 0) * factor).rounded()), for: member)
            }
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
        }

        if !Task.isCancelled {
            for group in playing {
                try? await SonosController(host: group.coordinator.host).pause()
            }
            try? await Task.sleep(for: .seconds(1))
        }

        for member in members {
            setVolume(originals[member.id] ?? 0, for: member)
        }
        await refreshStates()
    }
}
