import SwiftUI

struct HeroScrubber: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup
    let nowPlaying: NowPlaying

    @State private var hoverFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = nowPlaying.duration ?? 0
            let position = nowPlaying.position(at: context.date)
            let fraction = duration > 0 ? position / duration : 0

            VStack(spacing: 4) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white.opacity(0.9)).frame(width: width * fraction)
                        if let hoverFraction {
                            Capsule().fill(.white.opacity(0.3)).frame(width: width * hoverFraction)
                        }
                    }
                    .frame(height: hoverFraction == nil ? 4 : 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location): hoverFraction = clamp(location.x / width)
                        case .ended: hoverFraction = nil
                        }
                    }
                    .onTapGesture { location in
                        store.seek(group, to: clamp(location.x / width) * duration)
                    }
                }
                .frame(height: 12)
                .animation(.spring(duration: 0.2), value: hoverFraction == nil)

                HStack {
                    Text(TimeFormat.clock(hoverFraction.map { $0 * duration } ?? position))
                    Spacer()
                    Text("-" + TimeFormat.clock(max(duration - position, 0)))
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .opacity(0.6)
            }
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
