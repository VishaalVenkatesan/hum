import Foundation
import Observation

struct LyricLine: Equatable, Sendable {
    let time: TimeInterval
    let text: String
}

enum Lyrics: Equatable, Sendable {
    case synced([LyricLine])
    case plain([String])
    case unavailable
}

@MainActor
@Observable
final class LyricsService {
    private(set) var cache: [String: Lyrics] = [:]

    @ObservationIgnored private var inFlight: Set<String> = []

    func lyrics(for nowPlaying: NowPlaying) -> Lyrics? {
        guard let key = Self.key(for: nowPlaying) else { return .unavailable }
        return cache[key]
    }

    func load(for nowPlaying: NowPlaying) async {
        guard
            let key = Self.key(for: nowPlaying),
            let title = nowPlaying.title,
            let artist = nowPlaying.artist,
            cache[key] == nil,
            !inFlight.contains(key)
        else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }
        cache[key] = await LRCLib.fetch(title: title, artist: artist, duration: nowPlaying.duration)
    }

    private static func key(for nowPlaying: NowPlaying) -> String? {
        guard let title = nowPlaying.title, let artist = nowPlaying.artist else { return nil }
        return "\(artist.lowercased())|\(title.lowercased())"
    }
}

private enum LRCLib {
    private struct Track: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
        let instrumental: Bool?
    }

    private static let base = "https://lrclib.net/api"

    static func fetch(title: String, artist: String, duration: TimeInterval?) async -> Lyrics {
        var exact: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let duration, duration > 0 {
            exact.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }

        if let track: Track = await request("/get", exact), let lyrics = lyrics(from: track) {
            return lyrics
        }
        let search = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let tracks: [Track] = await request("/search", search) {
            let best = tracks.first { $0.syncedLyrics?.isEmpty == false } ?? tracks.first
            if let best, let lyrics = lyrics(from: best) { return lyrics }
        }
        return .unavailable
    }

    private static func lyrics(from track: Track) -> Lyrics? {
        if let synced = track.syncedLyrics, !synced.isEmpty {
            let lines = parse(synced)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = track.plainLyrics, !plain.isEmpty {
            return .plain(plain.components(separatedBy: "\n"))
        }
        return track.instrumental == true ? .unavailable : nil
    }

    private static func request<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async -> T? {
        guard var components = URLComponents(string: base + path) else { return nil }
        components.queryItems = query
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Hum (macOS menu bar app)", forHTTPHeaderField: "User-Agent")
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func parse(_ synced: String) -> [LyricLine] {
        synced.components(separatedBy: "\n").compactMap { line in
            guard
                line.hasPrefix("["),
                let close = line.firstIndex(of: "]")
            else { return nil }
            let stamp = line[line.index(after: line.startIndex)..<close].split(separator: ":")
            guard stamp.count == 2, let minutes = Double(stamp[0]), let seconds = Double(stamp[1]) else { return nil }
            let text = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            return LyricLine(time: minutes * 60 + seconds, text: text)
        }
    }
}
