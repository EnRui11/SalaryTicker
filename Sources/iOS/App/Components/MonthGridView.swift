import SwiftUI
import SalaryDomain
import SalaryShared

/// The month as a grid, so the workday count stops being an abstract number.
///
/// Solid squares are workdays already behind you, outlined ones are still to come, today is
/// ringed. Tapping a scheduled day cycles it through paid holiday and unpaid leave, which
/// is the whole reason this is on the phone: marking Merdeka the morning it is announced
/// should not require going home to a Mac. Touching and holding one opens its menu, which
/// is the only way to a half day of leave.
struct MonthGridView: View {
    let overview: MonthOverview
    let text: Strings
    let title: String
    let isCurrentMonth: Bool
    let onToggleDay: (DayKey) -> Void
    let onSetDay: (DayKey, DayOverride?) -> Void
    let onStepMonth: (Int) -> Void
    let onShowCurrentMonth: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Blanks and days share one identified list. Two `ForEach`es inside one grid put plain
    /// integers in the same identity space, and the blanks' 1…5 collide with the 1st–5th.
    private struct Cell: Identifiable {
        let id: Int
        let day: MonthDay?
    }

    private var cells: [Cell] {
        (0..<overview.leadingBlanks).map { Cell(id: -($0 + 1), day: nil) }
            + overview.days.map { Cell(id: $0.day, day: $0) }
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(text.weekdayInitials, id: \.self) { initial in
                    Text(initial)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(cells) { cell in
                    if let day = cell.day { square(day) } else { Color.clear.frame(height: 34) }
                }
            }
            legend
        }
    }

    private var header: some View {
        HStack {
            Button { onStepMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(text.previousMonth)
            Spacer()
            Button { onShowCurrentMonth() } label: {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isCurrentMonth ? .secondary : Color.accentColor)
            }
            .disabled(isCurrentMonth)
            .accessibilityHint(isCurrentMonth ? "" : text.backToThisMonth)
            Spacer()
            Button { onStepMonth(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(text.nextMonth)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func square(_ day: MonthDay) -> some View {
        Button {
            if day.isScheduled { onToggleDay(day.key) }
        } label: {
            Text("\(day.day)")
                .font(.footnote.monospacedDigit())
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(fill(for: day))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(borderColour(for: day), lineWidth: day.isToday ? 2 : 1)
                )
                .foregroundStyle(textColour(for: day))
        }
        .buttonStyle(.plain)
        .disabled(!day.isScheduled)
        .contextMenu { if day.isScheduled { dayMenu(for: day) } }
        .accessibilityLabel(label(for: day))
    }

    // MARK: The day's menu

    /// Every state a day can be in, ticked where it is now. The tap cycle still covers
    /// the common three; the half days live here.
    @ViewBuilder private func dayMenu(for day: MonthDay) -> some View {
        menuItem(text.menuWorkday, nil, day)
        menuItem(text.menuPaidHoliday, .paidLeave, day)
        menuItem(text.menuUnpaidLeave, .unpaidLeave, day)
        // One section, no divider. A menu reserves the tick's column per section, so a
        // divider here left the two half days sitting a column to the left of the three
        // above them whenever the tick was up there.
        menuItem(text.menuMorningOff, .unpaidMorning, day)
        menuItem(text.menuAfternoonOff, .unpaidAfternoon, day)
    }

    private func menuItem(_ title: String, _ state: DayOverride?, _ day: MonthDay) -> some View {
        Button { onSetDay(day.key, state) } label: {
            if day.override == state {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder private func fill(for day: MonthDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        switch day.override {
        case .paidLeave: shape.fill(Color.orange.opacity(0.22))
        case .unpaidLeave: shape.fill(Color(.tertiarySystemFill))
        // Drawn as the two halves it is — morning on the left, afternoon on the right, the
        // half taken off in the unpaid grey — so it reads as half a day without a legend.
        case .unpaidMorning:
            HStack(spacing: 0) { halfOff; halfWorked(day) }.clipShape(shape)
        case .unpaidAfternoon:
            HStack(spacing: 0) { halfWorked(day); halfOff }.clipShape(shape)
        case nil:
            if !day.isScheduled { shape.fill(Color.clear) }
            else if day.isPast { shape.fill(Color.accentColor) }
            else { shape.fill(Color.accentColor.opacity(0.12)) }
        }
    }

    private var halfOff: Color { Color(.tertiarySystemFill) }

    /// Paler than a whole worked day even once past, so the date stays readable on it.
    private func halfWorked(_ day: MonthDay) -> Color {
        Color.accentColor.opacity(day.isPast ? 0.45 : 0.12)
    }

    private func borderColour(for day: MonthDay) -> Color {
        if day.isToday { return .accentColor }
        if !day.isScheduled { return .clear }
        return day.override == nil ? Color.accentColor.opacity(0.35) : Color(.separator)
    }

    private func textColour(for day: MonthDay) -> Color {
        if !day.isScheduled { return .secondary }
        if day.override == nil && day.isPast { return .white }
        return .primary
    }

    private func label(for day: MonthDay) -> String {
        var parts = ["\(day.day)"]
        switch day.override {
        case .paidLeave: parts.append(text.legendPaidLeave)
        case .unpaidLeave: parts.append(text.legendUnpaidLeave)
        // Named explicitly: without these the `default` below read a half day of leave to
        // a screen reader as a whole day off.
        case .unpaidMorning: parts.append(text.menuMorningOff)
        case .unpaidAfternoon: parts.append(text.menuAfternoonOff)
        case nil where day.isScheduled: parts.append(day.isPast ? text.legendWorked : text.legendUpcoming)
        default: parts.append(text.dayOff)
        }
        if day.isHalfDay { parts.append(text.halfDay) }
        return parts.joined(separator: ", ")
    }

    /// Two rows rather than one: five swatches do not fit across a phone in the longer
    /// languages, and a legend that truncates is a legend that lies about what is there.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                swatch(Color.accentColor, text.legendWorked)
                swatch(Color.accentColor.opacity(0.12), text.legendUpcoming)
                swatch(Color.orange.opacity(0.22), text.legendPaidLeave)
            }
            HStack(spacing: 12) {
                swatch(Color(.tertiarySystemFill), text.legendUnpaidLeave)
                HStack(spacing: 4) {
                    HStack(spacing: 0) { halfOff; Color.accentColor.opacity(0.12) }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .frame(width: 9, height: 9)
                    Text(text.legendHalfDayOff).lineLimit(1)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatch(_ colour: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(colour).frame(width: 9, height: 9)
            Text(label).lineLimit(1)
        }
    }
}
