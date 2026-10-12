import Foundation

enum PlaybackSource: Equatable, Sendable {
    case spotify(trackID: String?)
    case service(String)
    case airPlay
    case lineIn
    case tv
    case radio
    case library
    case unknown

    var title: String? {
        switch self {
        case .spotify: "Spotify"
        case .service(let name): name
        case .airPlay: "AirPlay"
        case .lineIn: "Line-In"
        case .tv: "TV"
        case .radio: "Radio"
        case .library: "Library"
        case .unknown: nil
        }
    }

    var symbol: String {
        switch self {
        case .spotify, .service: "music.note"
        case .airPlay: "airplayaudio"
        case .lineIn: "cable.connector"
        case .tv: "tv"
        case .radio: "dot.radiowaves.left.and.right"
        case .library: "music.note.house"
        case .unknown: "music.note"
        }
    }

    var appURL: URL? {
        guard case .spotify(let id?) = self else { return nil }
        return URL(string: "spotify:track:\(id)")
    }

    var shareURL: URL? {
        guard case .spotify(let id?) = self else { return nil }
        return URL(string: "https://open.spotify.com/track/\(id)")
    }

    private static let services = [
        "12": "Spotify",
        "204": "Apple Music",
        "201": "Amazon Music",
        "174": "TIDAL",
        "284": "YouTube Music"
    ]

    private static let radioPrefixes = ["x-sonosapi-stream:", "x-sonosapi-radio:", "x-rincon-mp3radio:", "x-sonosapi-hls:", "x-sonosprog-http:", "pndrradio:"]

    static func detect(resource: String?, trackURI: String?, mediaURI: String?, mediaTitle: String?) -> PlaybackSource {
        let raw = [resource, trackURI, mediaURI].compactMap { $0 }.joined(separator: " ")
        let text = raw.removingPercentEncoding ?? raw
        let lower = text.lowercased()
        let media = mediaURI?.lowercased() ?? ""

        if let range = text.range(of: "spotify:track:[A-Za-z0-9]+", options: .regularExpression) {
            return .spotify(trackID: String(text[range].dropFirst("spotify:track:".count)))
        }
        if lower.contains("spotify") { return .spotify(trackID: nil) }
        if media.hasPrefix("x-sonos-vli"), lower.contains("airplay") { return .airPlay }
        if media.hasPrefix("x-rincon-stream:") { return .lineIn }
        if media.hasPrefix("x-sonos-htastream:") { return .tv }
        if radioPrefixes.contains(where: media.hasPrefix) { return .radio }
        if let range = lower.range(of: "sid=[0-9]+", options: .regularExpression),
           let name = services[String(lower[range].dropFirst(4))] {
            return .service(name)
        }
        if lower.contains("x-file-cifs") || lower.contains("x-smb") { return .library }
        if media.hasPrefix("x-sonos-vli"), let mediaTitle, !mediaTitle.isEmpty { return .service(mediaTitle) }
        return .unknown
    }
}

struct AudioQuality: Equatable, Sendable {
    let bitDepth: Int
    let sampleRate: Int

    var isHiRes: Bool { bitDepth >= 24 || sampleRate > 48_000 }

    var label: String {
        let kHz = String(format: "%g", Double(sampleRate) / 1000)
        return "\(bitDepth)-bit · \(kHz) kHz"
    }

    init?(streamInfo: String?) {
        guard let streamInfo else { return nil }
        var values: [String: Int] = [:]
        for pair in streamInfo.split(separator: ",") {
            let parts = pair.split(separator: ":")
            if parts.count == 2, let value = Int(parts[1]) { values[String(parts[0])] = value }
        }
        guard let depth = values["bd"], let rate = values["sr"], depth > 0, rate > 0 else { return nil }
        bitDepth = depth
        sampleRate = rate
    }
}

enum RepeatMode: Equatable, Sendable {
    case off
    case all
    case one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

struct PlayMode: Equatable, Sendable {
    var shuffle: Bool
    var repeatMode: RepeatMode

    init(shuffle: Bool, repeatMode: RepeatMode) {
        self.shuffle = shuffle
        self.repeatMode = repeatMode
    }

    init?(raw: String?) {
        switch raw {
        case "NORMAL": self.init(shuffle: false, repeatMode: .off)
        case "REPEAT_ALL": self.init(shuffle: false, repeatMode: .all)
        case "REPEAT_ONE": self.init(shuffle: false, repeatMode: .one)
        case "SHUFFLE_NOREPEAT": self.init(shuffle: true, repeatMode: .off)
        case "SHUFFLE": self.init(shuffle: true, repeatMode: .all)
        case "SHUFFLE_REPEAT_ONE": self.init(shuffle: true, repeatMode: .one)
        default: return nil
        }
    }

    var raw: String {
        switch (shuffle, repeatMode) {
        case (false, .off): "NORMAL"
        case (false, .all): "REPEAT_ALL"
        case (false, .one): "REPEAT_ONE"
        case (true, .off): "SHUFFLE_NOREPEAT"
        case (true, .all): "SHUFFLE"
        case (true, .one): "SHUFFLE_REPEAT_ONE"
        }
    }
}

struct SpeakerInfo: Equatable, Sendable {
    var model: String?
    var firmware: String?
    var statusLight: Bool
    var buttonsLocked: Bool
}
