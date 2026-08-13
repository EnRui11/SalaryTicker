import SwiftUI
import SalaryDomain
import SalaryShared

/// Which weekdays are worked, and which of those are half days.
///
/// Sized for a thumb rather than a pointer — seven targets across a phone is tight, so the
/// tiles are as tall as they are wide and the half-day state is a mark inside the tile
/// rather than a second control beside it. One tap cycles off → full → half → off, which is
/// the same cycle the month grid uses for leave, so the gesture is learned once.
struct WeekdayPicker: View {
    @Binding var config: SalaryConfig
    let text: Strings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                tile(weekday)
            }
        }
    }

    private func tile(_ weekday: Int) -> some View {
        let weight = config.scheduledWeight(forWeekday: weekday)
        let name = text.weekdayInitials[weekday - 1]

        return Button {
            cycle(weekday)
        } label: {
            VStack(spacing: 2) {
                Text(name)
                    .font(.footnote.weight(weight > 0 ? .semibold : .regular))
                Text(weight == 0.5 ? text.halfDay : " ")
                    .font(.system(size: 8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(weight == 0.5 ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(background(for: weight))
            .foregroundStyle(weight >= 1 ? Color.white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(weight == 0 ? text.dayOff : (weight < 1 ? text.halfDay : text.legendWorked))
    }

    @ViewBuilder private func background(for weight: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if weight >= 1 {
            shape.fill(Color.accentColor)
        } else if weight > 0 {
            // Half days read as "partly on": the accent, but as a tint rather than a fill.
            shape.fill(Color.accentColor.opacity(0.18))
                .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 1))
        } else {
            shape.fill(Color(.tertiarySystemFill))
        }
    }

    private func cycle(_ weekday: Int) {
        if !config.workdays.contains(weekday) {
            config.workdays.insert(weekday)
            config.halfDays.remove(weekday)
        } else if !config.halfDays.contains(weekday) {
            config.halfDays.insert(weekday)
        } else {
            config.workdays.remove(weekday)
            config.halfDays.remove(weekday)
        }
    }
}
