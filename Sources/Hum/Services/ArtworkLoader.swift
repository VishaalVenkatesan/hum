import AppKit
import Observation
import SwiftUI

struct Artwork {
    let image: NSImage
    let tint: Color
}

@MainActor
@Observable
final class ArtworkLoader {
    private(set) var cache: [URL: Artwork] = [:]

    @ObservationIgnored private var inFlight: Set<URL> = []
    @ObservationIgnored private var order: [URL] = []
    private static let capacity = 24

    func artwork(for url: URL?) -> Artwork? {
        url.flatMap { cache[$0] }
    }

    func load(_ url: URL?) async {
        guard let url, cache[url] == nil, !inFlight.contains(url) else { return }
        inFlight.insert(url)
        defer { inFlight.remove(url) }

        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let image = NSImage(data: data)
        else { return }

        cache[url] = Artwork(image: image, tint: Self.tint(of: image))
        order.append(url)
        if order.count > Self.capacity {
            cache[order.removeFirst()] = nil
        }
    }

    private static func tint(of image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .accentColor }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .accentColor }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let average = NSColor(
            srgbRed: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        let vivid = NSColor(
            hue: average.hueComponent,
            saturation: min(average.saturationComponent * 1.6, 0.85),
            brightness: max(average.brightnessComponent, 0.55),
            alpha: 1
        )
        return Color(nsColor: vivid)
    }
}
