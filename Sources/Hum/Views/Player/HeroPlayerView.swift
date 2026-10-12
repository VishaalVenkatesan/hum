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
            HStack {
                RoomPickerMenu(group: group)
                Spacer()
                EqualizerBars(isAnimating: nowPlaying.state.isPlaying, barCount: 4)
                    .opacity(nowPlaying.state.isPlaying ? 0.9 : 0.35)
            }

            HStack(spacing: 14) {
                ArtTile(image: art?.image, isPlaying: nowPlaying.state.isPlaying)
                TrackInfo(nowPlaying: nowPlaying, fallback: group.name)
            }

            if nowPlaying.hasProgress {
                HeroScrubber(group: group, nowPlaying: nowPlaying)
            }

            TransportRow(group: group, isPlaying: nowPlaying.state.isPlaying, showLyrics: $showLyrics)

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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: isPlaying ? 10 : 4, y: isPlaying ? 6 : 2)
        .scaleEffect(isPlaying ? 1 : 0.9)
        .animation(.spring(duration: 0.5, bounce: 0.35), value: isPlaying)
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

private struct TransportRow: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup
    let isPlaying: Bool
    @Binding var showLyrics: Bool

    var body: some View {
        HStack {
            Button {
                showLyrics.toggle()
            } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 14))
                    .frame(width: 30, height: 30)
                    .opacity(showLyrics ? 1 : 0.7)
            }
            .help(showLyrics ? "Hide lyrics" : "Show lyrics")

            Spacer()

            Button { store.previous(group) } label: {
                Image(systemName: "backward.fill").font(.system(size: 18)).frame(width: 36, height: 36)
            }

            Button { store.togglePlayback(group) } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
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

            MoveMusicMenu(group: group)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(PressableStyle())
    }
}
