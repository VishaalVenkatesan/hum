import SwiftUI

struct EqualizerBars: View {
    let isAnimating: Bool
    var barCount = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .frame(width: 2.5, height: height(index: index, time: time))
                }
            }
            .frame(height: 12, alignment: .bottom)
        }
    }

    private func height(index: Int, time: TimeInterval) -> CGFloat {
        guard isAnimating else { return 3 }
        let speed = 3.1 + Double(index) * 1.7
        let wave = abs(sin(time * speed + Double(index) * 1.3)) * 0.7 + abs(sin(time * speed * 0.37)) * 0.3
        return 3 + 9 * wave
    }
}
