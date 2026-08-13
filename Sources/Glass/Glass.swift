import SwiftUI

// Liquid Glass, shared by the menu bar, the phone and the watch so the three cannot drift
// into three different ideas of the same look.
//
// The hand-rolled version this replaces stacked a material, a gradient rim and a shadow to
// imitate glass. The system does all three properly and does the parts imitation cannot:
// the specular highlight tracks the light, the edge bends what is behind it, and adjacent
// panes inside a container merge and separate as they move rather than sliding over one
// another like stickers.
//
// Two rules are kept from the design brief and are not the framework's job. Glass goes on a
// few surfaces per screen and not on all of them — stacked panes stop reading as depth and
// start reading as fog. And a backdrop with something in it is still required: glass over a
// flat colour is a slightly wrong grey no matter who draws it.

/// A backdrop worth putting glass over.
///
/// Radial gradients rather than blurred circles. A blur is a render-pass effect: it does not
/// survive an offscreen capture, and it sizes in points, so a wash tuned on a phone arrives
/// on a menu bar panel as two hard discs the size of the panel.
public struct GlassBackdrop: View {
    private let tint: Color

    public init(tint: Color = .accentColor) {
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            baseColour
            GeometryReader { proxy in
                let span = max(proxy.size.width, proxy.size.height)
                ZStack {
                    // One light direction, top-leading, held to on every surface.
                    RadialGradient(
                        colors: [tint.opacity(0.30), .clear],
                        center: .topLeading, startRadius: 0, endRadius: span * 0.9
                    )
                    RadialGradient(
                        colors: [tint.opacity(0.16), .clear],
                        center: .bottomTrailing, startRadius: 0, endRadius: span * 0.8
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

public extension View {
    /// Makes this a pane of glass.
    ///
    /// - Parameter elevated: the clear variant, which lets more of the backdrop through.
    ///   For the one surface on a screen that should feel closest to the reader.
    func glassPanel(radius: CGFloat = 16, elevated: Bool = false) -> some View {
        glassEffect(
            elevated ? .clear : .regular,
            in: .rect(cornerRadius: radius, style: .continuous)
        )
    }

    /// Marks a pane so it can merge with its neighbours inside a `GlassGroup`.
    func glassMember(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        glassEffectID(id, in: namespace)
    }
}

/// Groups panes that should behave as one piece of glass.
///
/// Without this each pane is independent and they slide over each other; inside it the
/// system lets them stretch towards each other and merge as they come close, which is the
/// whole reason the material is called liquid.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) { content }
    }
}
