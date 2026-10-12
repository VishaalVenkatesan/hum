import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class HUDModel {
    var symbol = "speaker.wave.2.fill"
    var title: String?
    var level: Int?
}

@MainActor
final class HUDController {
    private let model = HUDModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(symbol: String, title: String? = nil, level: Int? = nil) {
        model.symbol = symbol
        model.title = title
        model.level = level

        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 120))
    }
}

private struct HUDView: View {
    let model: HUDModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: model.symbol)
                .font(.system(size: 64, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(height: 80)

            if let title = model.title {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if let level = model.level {
                LevelPips(level: level)
            }
        }
        .foregroundStyle(.primary)
        .padding(20)
        .frame(width: 200, height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .frame(width: 220, height: 220)
    }
}

private struct LevelPips: View {
    let level: Int
    private static let count = 16

    var body: some View {
        let lit = Int((Double(level) / 100 * Double(Self.count)).rounded())
        HStack(spacing: 2) {
            ForEach(0..<Self.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < lit ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.12), value: lit)
    }
}
