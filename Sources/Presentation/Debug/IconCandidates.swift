import SwiftUI

/// Candidate app icons, drawn in SwiftUI so they can be regenerated at any size without a
/// design tool or a binary asset in the repository.
///
///     SalaryTicker --render-icons <dir>
///
/// Each candidate is rendered large and small, because the small one decides: at 16 or 32
/// points a Finder list view keeps only the silhouette and one strong shape.
enum IconCandidate: String, CaseIterable {
    case coin
    case banknote
    case dial
    /// Real coins are minted with animals on them, so an animal on the coin face reads as
    /// a coin rather than as a mascot stuck on top of one.
    case fishCoin
    case catCoin
    case fishHero
    case milledDollar

    @ViewBuilder
    var view: some View {
        switch self {
        case .coin: CoinIcon()
        case .banknote: BanknoteIcon()
        case .dial: DialIcon()
        case .fishCoin: MintedCoinIcon(symbol: "fish.fill")
        case .catCoin: MintedCoinIcon(symbol: "cat.fill")
        case .fishHero: FishHeroIcon()
        case .milledDollar: MilledDollarIcon()
        }
    }
}

// MARK: - Shared chrome

/// The macOS icon body: a squircle inset from the canvas, the way the system grid expects.
private struct IconBody<Content: View>: View {
    var background: LinearGradient
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let body = size * 0.82
            ZStack {
                RoundedRectangle(cornerRadius: body * 0.2237, style: .continuous)
                    .fill(background)
                    .frame(width: body, height: body)
                    .shadow(color: .black.opacity(0.28), radius: size * 0.02, y: size * 0.012)
                content(body)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private let goldFace = RadialGradient(
    colors: [Color(red: 1.00, green: 0.86, blue: 0.45), Color(red: 0.90, green: 0.63, blue: 0.13)],
    center: .init(x: 0.35, y: 0.30), startRadius: 0, endRadius: 320
)

// MARK: - A. Coin inside a progress ring

private struct CoinIcon: View {
    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.16, green: 0.20, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.14)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) { body in
            ZStack {
                // The day's progress, the same arc the panel draws.
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: body * 0.085)
                    .frame(width: body * 0.66, height: body * 0.66)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.25, green: 0.70, blue: 1.0),
                                                Color(red: 0.10, green: 0.45, blue: 0.95)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: body * 0.085, lineCap: .round)
                    )
                    .frame(width: body * 0.66, height: body * 0.66)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(goldFace)
                    .frame(width: body * 0.42, height: body * 0.42)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: body * 0.012)
                    )
            }
        }
    }
}

// MARK: - Milled coin with a struck dollar

private struct MilledDollarIcon: View {
    /// Enough teeth to read as milling, few enough that they do not merge into a smear at
    /// the sizes where they still show at all.
    private let teeth = 64

    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.16, green: 0.20, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.14)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) { body in
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: body * 0.085)
                    .frame(width: body * 0.70, height: body * 0.70)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.25, green: 0.70, blue: 1.0),
                                                Color(red: 0.10, green: 0.45, blue: 0.95)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: body * 0.085, lineCap: .round)
                    )
                    .frame(width: body * 0.70, height: body * 0.70)
                    .rotationEffect(.degrees(-90))

                coin(body: body)
            }
        }
    }

    private func coin(body: CGFloat) -> some View {
        let diameter = body * 0.50
        return ZStack {
            Circle()
                .fill(goldFace)
                .frame(width: diameter, height: diameter)

            // Milling sits in a band just inside the edge, because that is where it is on a
            // real coin: face-on you see a textured ring at the perimeter, not spokes
            // radiating out of it. Teeth that overhang the disc read as a gear.
            ForEach(0..<teeth, id: \.self) { tooth in
                Capsule()
                    .fill(Color(red: 0.66, green: 0.44, blue: 0.06).opacity(0.85))
                    .frame(width: diameter * 0.022, height: diameter * 0.055)
                    .offset(y: -diameter * 0.468)
                    .rotationEffect(.degrees(Double(tooth) / Double(teeth) * 360))
            }

            // The raised inner rim a struck coin has just inside its milled edge.
            Circle()
                .strokeBorder(Color(red: 0.62, green: 0.42, blue: 0.06).opacity(0.45),
                              lineWidth: diameter * 0.018)
                .frame(width: diameter * 0.80, height: diameter * 0.80)

            Text("$")
                .font(.system(size: diameter * 0.56, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.50, green: 0.32, blue: 0.03))
                .shadow(color: .white.opacity(0.5), radius: 0, y: diameter * 0.012)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Coin with an animal minted on the face

private struct MintedCoinIcon: View {
    let symbol: String

    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.16, green: 0.20, blue: 0.28), Color(red: 0.07, green: 0.09, blue: 0.14)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) { body in
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: body * 0.085)
                    .frame(width: body * 0.66, height: body * 0.66)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.25, green: 0.70, blue: 1.0),
                                                Color(red: 0.10, green: 0.45, blue: 0.95)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: body * 0.085, lineCap: .round)
                    )
                    .frame(width: body * 0.66, height: body * 0.66)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(goldFace)
                    .frame(width: body * 0.46, height: body * 0.46)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: body * 0.012)
                    )

                // Struck into the coin rather than laid on it: a dark relief with a hairline
                // highlight below, which is what makes a minted face read as minted.
                Image(systemName: symbol)
                    .font(.system(size: body * 0.24, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.33, blue: 0.04).opacity(0.92))
                    .shadow(color: .white.opacity(0.45), radius: 0, y: body * 0.006)
            }
        }
    }
}

// MARK: - Fish as the hero, coin demoted to a ring

private struct FishHeroIcon: View {
    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.10, green: 0.30, blue: 0.46), Color(red: 0.04, green: 0.13, blue: 0.24)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) { body in
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: body * 0.05, lineCap: .round))
                    .frame(width: body * 0.76, height: body * 0.76)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "fish.fill")
                    .font(.system(size: body * 0.46, weight: .semibold))
                    .foregroundStyle(goldFace)
            }
        }
    }
}

// MARK: - B. Banknote with a second hand

private struct BanknoteIcon: View {
    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.13, green: 0.60, blue: 0.42), Color(red: 0.05, green: 0.34, blue: 0.26)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) { body in
            ZStack {
                RoundedRectangle(cornerRadius: body * 0.06, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(width: body * 0.66, height: body * 0.40)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(red: 0.13, green: 0.55, blue: 0.40), lineWidth: body * 0.022)
                            .frame(width: body * 0.16, height: body * 0.16)
                    )
                    .rotationEffect(.degrees(-8))

                // The hand: one stroke that turns a banknote into a clock.
                Capsule()
                    .fill(Color(red: 0.10, green: 0.16, blue: 0.14))
                    .frame(width: body * 0.028, height: body * 0.30)
                    .offset(y: -body * 0.10)
                    .rotationEffect(.degrees(38))
                Circle()
                    .fill(Color(red: 0.10, green: 0.16, blue: 0.14))
                    .frame(width: body * 0.055, height: body * 0.055)
            }
        }
    }
}

// MARK: - C. Clock dial with a gold hand

private struct DialIcon: View {
    var body: some View {
        IconBody(background: LinearGradient(
            colors: [Color(red: 0.22, green: 0.24, blue: 0.28), Color(red: 0.09, green: 0.10, blue: 0.12)],
            startPoint: .top, endPoint: .bottom
        )) { body in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: body * 0.72, height: body * 0.72)

                ForEach(0..<12, id: \.self) { tick in
                    Capsule()
                        .fill(Color.white.opacity(tick % 3 == 0 ? 0.85 : 0.35))
                        .frame(width: body * 0.022, height: body * (tick % 3 == 0 ? 0.075 : 0.045))
                        .offset(y: -body * 0.30)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }

                Capsule()
                    .fill(goldFace)
                    .frame(width: body * 0.045, height: body * 0.30)
                    .offset(y: -body * 0.10)
                    .rotationEffect(.degrees(125))

                Circle()
                    .fill(goldFace)
                    .frame(width: body * 0.10, height: body * 0.10)
            }
        }
    }
}
