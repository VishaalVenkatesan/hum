import Foundation

struct SonosController: Sendable {
    let host: String
    private var soap: SonosSOAP { SonosSOAP(host: host) }

    func topology() async throws -> [SonosGroup] {
        let response = try await soap.call(.zoneGroupTopology, "GetZoneGroupState")
        return TopologyParser.parse(response["ZoneGroupState"] ?? "")
    }

    func volume() async throws -> VolumeState {
        async let level = soap.call(.renderingControl, "GetVolume", ["InstanceID": "0", "Channel": "Master"])
        async let mute = soap.call(.renderingControl, "GetMute", ["InstanceID": "0", "Channel": "Master"])
        let (levelResponse, muteResponse) = try await (level, mute)
        return VolumeState(
            level: Int(levelResponse["CurrentVolume"] ?? "") ?? 0,
            muted: muteResponse["CurrentMute"] == "1"
        )
    }

    func setVolume(_ level: Int) async throws {
        try await soap.call(.renderingControl, "SetVolume", ["InstanceID": "0", "Channel": "Master", "DesiredVolume": String(min(max(level, 0), 100))])
    }

    func setMute(_ muted: Bool) async throws {
        try await soap.call(.renderingControl, "SetMute", ["InstanceID": "0", "Channel": "Master", "DesiredMute": muted ? "1" : "0"])
    }

    func nowPlaying() async throws -> NowPlaying {
        async let transport = soap.call(.avTransport, "GetTransportInfo", ["InstanceID": "0"])
        async let position = soap.call(.avTransport, "GetPositionInfo", ["InstanceID": "0"])
        async let media = try? soap.call(.avTransport, "GetMediaInfo", ["InstanceID": "0"])
        async let settings = try? soap.call(.avTransport, "GetTransportSettings", ["InstanceID": "0"])
        async let crossfade = try? soap.call(.avTransport, "GetCrossfadeMode", ["InstanceID": "0"])
        async let sleep = try? soap.call(.avTransport, "GetRemainingSleepTimerDuration", ["InstanceID": "0"])

        let (transportResponse, positionResponse) = try await (transport, position)
        let (mediaResponse, settingsResponse, crossfadeResponse, sleepResponse) = await (media, settings, crossfade, sleep)

        var result = DIDLParser.parse(positionResponse["TrackMetaData"] ?? "", host: host)
        let mediaTitle = DIDLParser.parse(mediaResponse?["CurrentURIMetaData"] ?? "", host: host).title
        let mediaURI = mediaResponse?["CurrentURI"]

        result.state = TransportState(rawValue: transportResponse["CurrentTransportState"] ?? "") ?? .unknown
        result.elapsed = TimeFormat.seconds(from: positionResponse["RelTime"])
        result.duration = TimeFormat.seconds(from: positionResponse["TrackDuration"])
        result.sampledAt = Date()
        result.source = PlaybackSource.detect(
            resource: result.resource,
            trackURI: positionResponse["TrackURI"],
            mediaURI: mediaURI,
            mediaTitle: mediaTitle
        )
        result.playMode = PlayMode(raw: settingsResponse?["PlayMode"])
        result.canChangePlayMode = mediaURI?.hasPrefix("x-rincon-queue:") == true
        result.crossfade = crossfadeResponse?["CrossfadeMode"] == "1"
        if let remaining = TimeFormat.seconds(from: sleepResponse?["RemainingSleepTimerDuration"]), remaining > 0 {
            result.sleepTimerEnd = Date().addingTimeInterval(remaining)
        }
        if result.title == nil {
            result.title = mediaTitle
        }
        return result
    }

    func setPlayMode(_ mode: PlayMode) async throws {
        try await soap.call(.avTransport, "SetPlayMode", ["InstanceID": "0", "NewPlayMode": mode.raw])
    }

    func setCrossfade(_ enabled: Bool) async throws {
        try await soap.call(.avTransport, "SetCrossfadeMode", ["InstanceID": "0", "CrossfadeMode": enabled ? "1" : "0"])
    }

    func configureSleepTimer(_ duration: TimeInterval?) async throws {
        let value = duration.map { TimeFormat.clock($0, alwaysHours: true) } ?? ""
        try await soap.call(.avTransport, "ConfigureSleepTimer", ["InstanceID": "0", "NewSleepTimerDuration": value])
    }

    func speakerInfo() async throws -> SpeakerInfo {
        async let zone = soap.call(.deviceProperties, "GetZoneInfo")
        async let led = soap.call(.deviceProperties, "GetLEDState")
        async let lock = soap.call(.deviceProperties, "GetButtonLockState")
        async let description = try? soap.text(at: "/xml/device_description.xml")

        let (zoneResponse, ledResponse, lockResponse) = try await (zone, led, lock)
        let model = await description.flatMap { xml -> String? in
            guard let start = xml.range(of: "<displayName>"), let end = xml.range(of: "</displayName>", range: start.upperBound..<xml.endIndex) else { return nil }
            return String(xml[start.upperBound..<end.lowerBound])
        }
        return SpeakerInfo(
            model: model,
            firmware: zoneResponse["DisplaySoftwareVersion"],
            statusLight: ledResponse["CurrentLEDState"] == "On",
            buttonsLocked: lockResponse["CurrentButtonLockState"] == "On"
        )
    }

    func setStatusLight(_ on: Bool) async throws {
        try await soap.call(.deviceProperties, "SetLEDState", ["DesiredLEDState": on ? "On" : "Off"])
    }

    func setButtonsLocked(_ locked: Bool) async throws {
        try await soap.call(.deviceProperties, "SetButtonLockState", ["DesiredButtonLockState": locked ? "On" : "Off"])
    }

    func play() async throws {
        try await soap.call(.avTransport, "Play", ["InstanceID": "0", "Speed": "1"])
    }

    func pause() async throws {
        try await soap.call(.avTransport, "Pause", ["InstanceID": "0"])
    }

    func next() async throws {
        try await soap.call(.avTransport, "Next", ["InstanceID": "0"])
    }

    func previous() async throws {
        try await soap.call(.avTransport, "Previous", ["InstanceID": "0"])
    }

    func seek(to seconds: TimeInterval) async throws {
        try await soap.call(.avTransport, "Seek", ["InstanceID": "0", "Unit": "REL_TIME", "Target": TimeFormat.clock(seconds, alwaysHours: true)])
    }

    func soundSettings() async throws -> SoundSettings {
        async let bass = soap.call(.renderingControl, "GetBass", ["InstanceID": "0"])
        async let treble = soap.call(.renderingControl, "GetTreble", ["InstanceID": "0"])
        async let loudness = soap.call(.renderingControl, "GetLoudness", ["InstanceID": "0", "Channel": "Master"])
        let (bassResponse, trebleResponse, loudnessResponse) = try await (bass, treble, loudness)
        return SoundSettings(
            bass: Int(bassResponse["CurrentBass"] ?? "") ?? 0,
            treble: Int(trebleResponse["CurrentTreble"] ?? "") ?? 0,
            loudness: loudnessResponse["CurrentLoudness"] == "1"
        )
    }

    func setBass(_ level: Int) async throws {
        try await soap.call(.renderingControl, "SetBass", ["InstanceID": "0", "DesiredBass": String(level)])
    }

    func setTreble(_ level: Int) async throws {
        try await soap.call(.renderingControl, "SetTreble", ["InstanceID": "0", "DesiredTreble": String(level)])
    }

    func setLoudness(_ enabled: Bool) async throws {
        try await soap.call(.renderingControl, "SetLoudness", ["InstanceID": "0", "Channel": "Master", "DesiredLoudness": enabled ? "1" : "0"])
    }

    func delegateCoordination(to memberID: String) async throws {
        try await soap.call(.avTransport, "DelegateGroupCoordinationTo", ["InstanceID": "0", "NewCoordinator": memberID, "RejoinGroup": "0"])
    }

    func join(coordinatorID: String) async throws {
        try await soap.call(.avTransport, "SetAVTransportURI", ["InstanceID": "0", "CurrentURI": "x-rincon:\(coordinatorID)", "CurrentURIMetaData": ""])
    }

    func leaveGroup() async throws {
        try await soap.call(.avTransport, "BecomeCoordinatorOfStandaloneGroup", ["InstanceID": "0"])
    }
}
