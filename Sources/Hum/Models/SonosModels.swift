import Foundation

struct SonosMember: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let host: String
}

struct SonosGroup: Identifiable, Hashable, Sendable {
    let id: String
    let coordinator: SonosMember
    let members: [SonosMember]

    var name: String {
        let others = members.filter { $0.id != coordinator.id }
        return others.isEmpty ? coordinator.name : "\(coordinator.name) + \(others.count)"
    }
}

enum TransportState: String, Sendable {
    case playing = "PLAYING"
    case paused = "PAUSED_PLAYBACK"
    case stopped = "STOPPED"
    case transitioning = "TRANSITIONING"
    case unknown

    var isPlaying: Bool { self == .playing || self == .transitioning }
}

struct NowPlaying: Equatable, Sendable {
    var state: TransportState = .unknown
    var title: String?
    var artist: String?
    var album: String?
    var artURL: URL?
    var elapsed: TimeInterval?
    var duration: TimeInterval?
    var sampledAt = Date()

    static let empty = NowPlaying()

    var hasProgress: Bool { (duration ?? 0) > 0 }

    func position(at date: Date) -> TimeInterval {
        let base = elapsed ?? 0
        let moving = state == .playing ? date.timeIntervalSince(sampledAt) : 0
        return min(base + max(moving, 0), duration ?? .greatestFiniteMagnitude)
    }

    var headline: String? {
        guard let title else { return nil }
        guard let artist else { return title }
        return "\(title) — \(artist)"
    }
}

struct VolumeState: Equatable, Sendable {
    var level: Int
    var muted: Bool
}

struct SoundSettings: Equatable, Sendable {
    var bass: Int
    var treble: Int
    var loudness: Bool

    static let flat = SoundSettings(bass: 0, treble: 0, loudness: true)
}
