import SwiftUI

// Glassmorphism, shared by the menu bar, the phone and the watch so the three cannot drift
// into three different ideas of the same look.
//
// The properties it is built to: a 10–30px blur, panels at roughly a quarter opacity, a
// low-contrast rim rather than a glowing border, one soft shadow from one light direction,
// and — the part that is easy to skip and fatal to skip — a backdrop with something in it.
// Glass over a flat colour is just a slightly wrong grey.
//
// Two rules from the same source are kept deliberately: glass goes on a few key surfaces
// rather than everything, and text is never tinted onto a tint. Labels stay on the system's
// semantic colours, which already meet contrast in both appearances; the glass sits behind
// them and never between them and the reader.

public extension ShapeStyle where Self == Material {
    /// The panel material. `ultraThin` rather than `thick`: the point is to see the
    /// backdrop move behind it.
    static var glassPanel: Material { .ultraThinMaterial }
}

/// A backdrop worth putting glass over.
///
/// Two soft washes of colour over the system background, blurred well past the point of
/// being shapes. Cheap — no image, nothing animating — and enough that the material has
/// something to refract instead of a flat field.
public struct GlassBackdrop: View {
    private let tint: Color

    public init(tint: Color = .accentColor) {
        self.tint = tint
    }

    public var body: some View {
        // Radial gradients rather than blurred circles. A blur is a render-pass effect: it
        // does not survive an offscreen capture, and it sizes in points, so a wash tuned on
        // a phone arrives on a menu bar panel as two hard discs the size of the panel.
        // Gradients scale with whatever they are given and cost nothing.
        ZStack {
            baseColour
            GeometryReader { proxy in
                let span = max(proxy.size.width, proxy.size.height)
                ZStack {
                    // One light direction, top-leading, held to on every surface.
                    RadialGradient(
                        colors: [tint.opacity(0.30), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: span * 0.9
                    )
                    RadialGradient(
                        colors: [tint.opacity(0.16), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: span * 0.8
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    private var baseColour: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #elseif os(watchOS)
        Color.black
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

/// One pane of glass.
///
/// The rim is a gradient rather than a stroke of one colour: a border of even brightness
/// reads as a drawn outline, while a highlight that fades away from the light reads as an
/// edge catching it.
public struct GlassPanel: ViewModifier {
    private let radius: CGFloat
    private let elevated: Bool

    public init(radius: CGFloat = 16, elevated: Bool = false) {
        self.radius = radius
        self.elevated = elevated
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(.glassPanel, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(
                color: .black.opacity(elevated ? 0.22 : 0.12),
                radius: elevated ? 18 : 10,
                x: 0,
                y: elevated ? 8 : 4
            )
    }
}

public extension View {
    /// Makes this a pane of glass. Used on a few surfaces per screen, never on all of them:
    /// stacked blurs stop reading as depth and start reading as fog.
    func glassPanel(radius: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(GlassPanel(radius: radius, elevated: elevated))
    }
}
