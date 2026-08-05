import AppKit
import SwiftUI

/// Today's progress as a small ring in the status item.
///
/// The same arc the panel and the app icon draw, but this is the one that is actually
/// live: empty before the day starts and on days off, filling through the day, complete
/// once you have clocked off.
///
/// Rendered to a **template image** rather than left as SwiftUI shapes, for two reasons.
/// `MenuBarExtra`'s label only reliably draws `Text` and `Image` — a bare `Circle` silently
/// renders as nothing. And a template image is what a menu bar glyph should be: macOS
/// tints it for a light or dark menu bar and inverts it while the menu is open, which
/// hand-picked colours cannot do.
struct MenuBarRingView: View, Equatable {
    /// Whole percent, so a day produces at most a hundred distinct images instead of one
    /// per second.
    let percent: Int

    var body: some View {
        Image(nsImage: MenuBarRingImages.image(percent: percent))
    }

    /// Lets SwiftUI skip this subtree entirely on the ticks where the percent has not
    /// moved — which is almost all of them, since a whole percent of an eight-hour day
    /// takes nearly five minutes to elapse. Without it the status item rebuilt the image
    /// every second and roughly doubled the app's idle CPU.
    nonisolated static func == (lhs: MenuBarRingView, rhs: MenuBarRingView) -> Bool {
        lhs.percent == rhs.percent
    }

    static func percent(of progress: Double) -> Int {
        guard progress.isFinite else { return 0 }
        return Int((min(max(progress, 0), 1) * 100).rounded())
    }
}

/// The rendered rings, kept so each percentage is drawn once per launch.
@MainActor
enum MenuBarRingImages {
    private static let side: CGFloat = 13
    private static let thickness: CGFloat = 2.2
    private static var cache: [Int: NSImage] = [:]

    static func image(percent: Int) -> NSImage {
        if let cached = cache[percent] { return cached }
        let image = render(fraction: Double(percent) / 100)
        cache[percent] = image
        return image
    }

    private static func render(fraction: Double) -> NSImage {
        let ring = ZStack {
            Circle()
                .stroke(Color.black.opacity(0.3), lineWidth: thickness)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.black, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: side - thickness, height: side - thickness)
        .padding(thickness / 2)

        let renderer = ImageRenderer(content: ring)
        renderer.scale = 2
        renderer.isOpaque = false

        guard let cgImage = renderer.cgImage else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
        // Template: the system decides the colour, so it stays legible on either menu bar
        // and inverts correctly when the item is highlighted.
        image.isTemplate = true
        return image
    }
}
