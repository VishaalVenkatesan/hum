import SwiftUI

struct LyricsView: View {
    @Environment(LyricsService.self) private var lyrics
    let nowPlaying: NowPlaying

    var body: some View {
        Group {
            switch lyrics.lyrics(for: nowPlaying) {
            case nil:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            case .unavailable:
                Text(nowPlaying.title == nil ? "Play something to see lyrics" : "No lyrics for this one")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.55)
                    .frame(maxWidth: .infinity)
            case .plain(let lines):
                ScrollView {
                    Text(lines.joined(separator: "\n"))
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
                .frame(height: 110)
            case .synced(let lines):
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    SyncedLyrics(lines: lines, index: currentIndex(in: lines, at: nowPlaying.position(at: context.date)))
                }
            }
        }
        .frame(minHeight: 100)
        .padding(12)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func currentIndex(in lines: [LyricLine], at position: TimeInterval) -> Int {
        lines.lastIndex { $0.time <= position + 0.3 } ?? -1
    }
}

private struct SyncedLyrics: View {
    let lines: [LyricLine]
    let index: Int

    private var visible: [(offset: Int, line: LyricLine)] {
        let start = max(index - 1, 0)
        let end = min(start + 4, lines.count)
        return (start..<end).map { ($0, lines[$0]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(visible, id: \.offset) { item in
                let isCurrent = item.offset == index
                Text(item.line.text.isEmpty ? "♪" : item.line.text)
                    .font(.system(size: isCurrent ? 16 : 13, weight: isCurrent ? .bold : .semibold))
                    .opacity(isCurrent ? 1 : item.offset < index ? 0.3 : 0.45)
                    .blur(radius: isCurrent ? 0 : 0.4)
                    .lineLimit(2)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.5, bounce: 0.15), value: index)
    }
}
