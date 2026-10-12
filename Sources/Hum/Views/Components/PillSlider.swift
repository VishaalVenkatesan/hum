import SwiftUI

struct PillSlider: View {
    let title: String
    let level: Int
    let muted: Bool
    var height: CGFloat = 34
    let onChange: (Int) -> Void
    let onToggleMute: () -> Void

    @State private var isDragging = false
    @State private var startedOnIcon = false
    @State private var isHovering = false

    private var fraction: CGFloat { muted ? 0 : CGFloat(level) / 100 }
    private var icon: String { muted ? "speaker.slash.fill" : AppController.volumeSymbol(for: level) }
    private var iconZone: CGFloat { height + 6 }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = width * fraction

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(isHovering ? 0.11 : 0.08))
                Rectangle()
                    .fill(Color.primary.opacity(muted ? 0.25 : 0.92))
                    .frame(width: fillWidth)
                label(color: .primary)
                label(color: Color(nsColor: .windowBackgroundColor))
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: fillWidth)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
            .gesture(drag(width: width))
            .onHover { isHovering = $0 }
        }
        .frame(height: height)
        .scaleEffect(isDragging ? 1.015 : 1)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isDragging)
        .animation(.easeOut(duration: 0.12), value: fraction)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(muted ? "Muted" : "\(level) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(level + 5, 100))
            case .decrement: onChange(max(level - 5, 0))
            @unknown default: break
            }
        }
    }

    private func label(color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(muted ? "Muted" : "\(level)")
                .monospacedDigit()
                .opacity(0.8)
        }
        .font(.system(size: height > 30 ? 12 : 11, weight: .semibold))
        .padding(.horizontal, 12)
        .foregroundStyle(color)
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    startedOnIcon = value.startLocation.x < iconZone
                }
                if startedOnIcon && abs(value.translation.width) < 3 { return }
                startedOnIcon = false
                let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                onChange(Int((ratio * 100).rounded()))
            }
            .onEnded { value in
                if startedOnIcon && abs(value.translation.width) < 3 {
                    onToggleMute()
                }
                isDragging = false
                startedOnIcon = false
            }
    }
}
