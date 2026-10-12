import AppKit
import SwiftUI

struct TransportRow: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup
    let nowPlaying: NowPlaying

    private var mode: PlayMode { nowPlaying.playMode ?? PlayMode(shuffle: false, repeatMode: .off) }
    private var modeEnabled: Bool { nowPlaying.canChangePlayMode }
    private var modeHelp: String? {
        guard !modeEnabled else { return nil }
        if case .spotify = nowPlaying.source { return "Spotify controls shuffle and repeat during Spotify Connect" }
        return "Shuffle and repeat work for music played from the speaker's queue"
    }

    var body: some View {
        HStack {
            ModeButton(symbol: "shuffle", isOn: mode.shuffle, isEnabled: modeEnabled, help: modeHelp ?? (mode.shuffle ? "Shuffle on" : "Shuffle off")) {
                store.setPlayMode(PlayMode(shuffle: !mode.shuffle, repeatMode: mode.repeatMode), for: group)
            }

            Spacer()

            Button { store.previous(group) } label: {
                Image(systemName: "backward.fill").font(.system(size: 18)).frame(width: 36, height: 36)
            }

            Button { store.togglePlayback(group) } label: {
                Image(systemName: nowPlaying.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
            .padding(.horizontal, 10)

            Button { store.next(group) } label: {
                Image(systemName: "forward.fill").font(.system(size: 18)).frame(width: 36, height: 36)
            }

            Spacer()

            ModeButton(
                symbol: mode.repeatMode == .one ? "repeat.1" : "repeat",
                isOn: mode.repeatMode != .off,
                isEnabled: modeEnabled,
                help: modeHelp ?? repeatHelp
            ) {
                store.setPlayMode(PlayMode(shuffle: mode.shuffle, repeatMode: mode.repeatMode.next), for: group)
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var repeatHelp: String {
        switch mode.repeatMode {
        case .off: "Repeat off"
        case .all: "Repeating all"
        case .one: "Repeating this song"
        }
    }
}

private struct ModeButton: View {
    let symbol: String
    let isOn: Bool
    let isEnabled: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(isOn && isEnabled ? 0.22 : 0)))
                .opacity(isEnabled ? (isOn ? 1 : 0.6) : 0.25)
        }
        .disabled(!isEnabled)
        .help(help)
        .animation(.spring(duration: 0.25), value: isOn)
    }
}

struct UtilityRow: View {
    let group: SonosGroup
    let nowPlaying: NowPlaying
    @Binding var showLyrics: Bool

    var body: some View {
        HStack(spacing: 4) {
            Button {
                showLyrics.toggle()
            } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .frame(width: 30, height: 26)
                    .opacity(showLyrics ? 1 : 0.6)
            }
            .help(showLyrics ? "Hide lyrics" : "Show lyrics")

            Spacer()

            if let quality = nowPlaying.quality {
                QualityBadge(quality: quality)
            }

            Spacer()

            ShareMenu(nowPlaying: nowPlaying)
                .frame(width: 30, height: 26)
            MoveMusicMenu(group: group)
                .frame(width: 30, height: 26)
        }
        .font(.system(size: 13))
        .buttonStyle(PressableStyle())
    }
}

struct SourceBadge: View {
    let source: PlaybackSource

    var body: some View {
        if let title = source.title {
            HStack(spacing: 4) {
                if case .spotify = source {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.84, blue: 0.38))
                        .frame(width: 6, height: 6)
                } else {
                    Image(systemName: source.symbol)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(title)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.white.opacity(0.12), in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

private struct QualityBadge: View {
    let quality: AudioQuality

    var body: some View {
        HStack(spacing: 4) {
            if quality.isHiRes {
                Text("HI-RES")
                    .font(.system(size: 8, weight: .heavy))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(.black)
            }
            Text(quality.label)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .opacity(0.6)
        }
        .help(quality.isHiRes ? "High-resolution audio" : "CD-quality audio")
    }
}

private struct ShareMenu: View {
    let nowPlaying: NowPlaying

    var body: some View {
        Menu {
            if let appURL = nowPlaying.source.appURL {
                Button("Open in Spotify") { NSWorkspace.shared.open(appURL) }
            }
            if let shareURL = nowPlaying.source.shareURL {
                Button("Copy Song Link") { copy(shareURL.absoluteString) }
            }
            if let headline = nowPlaying.headline {
                Button("Copy Song Name") { copy(headline) }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .opacity(nowPlaying.headline == nil ? 0.25 : 0.6)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(nowPlaying.headline == nil)
        .help("Share this song")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
