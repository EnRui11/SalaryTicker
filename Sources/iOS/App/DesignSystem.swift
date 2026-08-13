import SwiftUI
import SalaryGlass

// The pieces both screens are built from, in one place rather than copied per view.
//
// The design brief this follows is hoem-web's, and almost none of it transfers literally —
// there is no stylesheet here, no .card class, no save bar. What does transfer is the
// posture: flat and quiet, one accent, generous whitespace, and the data as the hero. On
// iOS that means system semantic colours rather than tokens, so both appearances are
// handled by the platform and neither is a special case.

/// A group of related facts. One bounded thing per card, stacked with air between them.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .glassPanel()
        }
    }
}

/// Label on the left, value on the right — the shape almost every settings row takes.
struct LabeledRow<Trailing: View>: View {
    let label: String
    var caption: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 11)
    }
}

extension LabeledRow where Trailing == Text {
    /// The read-only form: a derived figure the user cannot type into.
    init(_ label: String, _ value: String, caption: String? = nil) {
        self.init(label: label, caption: caption) {
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

/// A hairline between rows inside a card, inset to the text rather than the card edge.
struct RowDivider: View {
    var body: some View {
        Divider().overlay(Color(.separator))
    }
}

/// Explanatory text under a card. Quiet, and never competing with the rows above it.
struct CardCaption: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Nothing here yet, and what to do about it.
///
/// Empty states name the next move. "No goals" tells the reader something they already
/// know; the invitation is the part that helps.
struct EmptyHint: View {
    let icon: String
    let message: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
