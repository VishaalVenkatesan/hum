import SwiftUI

struct HeroPlayerView: View {
    @Environment(SpeakerStore.self) private var store
    @Environment(ArtworkLoader.self) private var artwork
    @Environment(LyricsService.self) private var lyrics
    @AppStorage(Preferences.showLyrics) private var showLyrics = false
    let group: SonosGroup

    private var nowPlaying: NowPlaying { store.nowPlaying[group.id] ?? .empty }
    private var art: Artwork? { artwork.artwork(for: nowPlaying.artURL) }
    private var lyricsTaskID: String { "\(showLyrics)|\(nowPlaying.title ?? "")|\(nowPlaying.artist ?? "")" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RoomPickerMenu(group: group)
                Spacer()
                SourceBadge(source: nowPlaying.source)
                EqualizerBars(isAnimating: nowPlaying.state.isPlaying, barCount: 4)
                    .opacity(nowPlaying.state.isPlaying ? 0.9 : 0.35)
            }

            HStack(spacing: 14) {
                ArtTile(image: art?.image, isPlaying: nowPlaying.state.isPlaying, openURL: nowPlaying.source.appURL)
                TrackInfo(nowPlaying: nowPlaying, fallback: group.name)
            }

            if nowPlaying.hasProgress {
                HeroScrubber(group: group, nowPlaying: nowPlaying)
            }

            TransportRow(group: group, nowPlaying: nowPlaying)
            UtilityRow(group: group, nowPlaying: nowPlaying, showLyrics: $showLyrics)

            if showLyrics {
                LyricsView(nowPlaying: nowPlaying)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .background { Backdrop(image: art?.image, tint: art?.tint) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
        .environment(\.colorScheme, .dark)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: showLyrics)
        .task(id: nowPlaying.artURL) { await artwork.load(nowPlaying.artURL) }
        .task(id: lyricsTaskID) {
            guard showLyrics else { return }
            await lyrics.load(for: nowPlaying)
        }
    }
}

private struct TrackInfo: View {
    let nowPlaying: NowPlaying
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(nowPlaying.title ?? "Nothing playing")
                .font(.system(size: 15, weight: .bold))
                .lineLimit(2)
            Text(nowPlaying.artist ?? fallback)
                .font(.system(size: 13, weight: .medium))
                .opacity(0.75)
                .lineLimit(1)
            if let album = nowPlaying.album {
                Text(album)
                    .font(.system(size: 11))
                    .opacity(0.5)
                    .lineLimit(1)
            }
        }
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: nowPlaying.title)
    }
}

private struct ArtTile: View {
    let image: NSImage?
    let isPlaying: Bool
    let openURL: URL?

    @State private var isHovering = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 26, weight: .medium))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.1))
            }
        }
        .frame(width: 76, height: 76)
        .overlay {
            if openURL != nil && isHovering {
                ZStack {
                    Color.black.opacity(0.45)
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 22))
                }
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: isPlaying ? 10 : 4, y: isPlaying ? 6 : 2)
        .scaleEffect(isPlaying ? 1 : 0.9)
        .animation(.spring(duration: 0.5, bounce: 0.35), value: isPlaying)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture {
            if let openURL { NSWorkspace.shared.open(openURL) }
        }
        .help(openURL == nil ? "" : "Open in Spotify")
    }
}

private struct Backdrop: View {
    let image: NSImage?
    let tint: Color?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.6)
                    .blur(radius: 45, opaque: true)
                    .saturation(1.5)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [tint ?? Color(white: 0.28), Color(white: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
        .animation(.easeInOut(duration: 0.6), value: image)
    }
}
