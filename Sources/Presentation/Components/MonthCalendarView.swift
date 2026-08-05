import SwiftUI
import SalaryDomain
import SalaryShared

/// The current month as a grid, so the workday count stops being an abstract number.
///
/// Filled squares are workdays; the solid ones are already behind you, the outlined ones
/// still to come. Today is ringed. Editing the weekday selection redraws it immediately,
/// which is the quickest way to see what a change actually costs.
struct MonthCalendarView: View {
    let overview: MonthOverview
    let text: Strings
    /// The month on screen, for the title.
    var monthTitle: String = ""
    /// False while browsing another month, which turns the title into a way back.
    var isCurrentMonth: Bool = true
    /// Called when a scheduled day is clicked, to cycle its holiday/leave state.
    var onToggleDay: ((DayKey) -> Void)?
    var onStepMonth: ((Int) -> Void)?
    var onShowCurrentMonth: (() -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Leading blanks and real days in one identified list.
    ///
    /// They have to share a single `ForEach`: two of them inside the same grid put plain
    /// `Int` ids in one identity space, so the blanks' 1…5 collided with the 1st–5th of
    /// the month and SwiftUI silently dropped those days from the grid.
    private struct Cell: Identifiable {
        let id: Int
        let day: MonthDay?
    }

    private var cells: [Cell] {
        let blanks = (0..<overview.leadingBlanks).map { Cell(id: $0, day: nil) }
        let days = overview.days.enumerated().map { offset, day in
            Cell(id: overview.leadingBlanks + offset, day: day)
        }
        return blanks + days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if onStepMonth != nil { header }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(text.weekdayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(cells) { cell in
                    if let day = cell.day {
                        if day.isScheduled, let onToggleDay {
                            Button { onToggleDay(day.key) } label: { self.cell(for: day) }
                                .buttonStyle(.plain)
                        } else {
                            self.cell(for: day)
                        }
                    } else {
                        Color.clear.frame(height: 22)
                    }
                }
            }
            legend
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button { onStepMonth?(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .accessibilityLabel(text.previousMonth)

            // The title doubles as the way home; browsing away is easy to do by accident.
            Button { onShowCurrentMonth?() } label: {
                Text(monthTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrentMonth ? Color.secondary : Color.accentColor)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .help(isCurrentMonth ? monthTitle : text.backToThisMonth)
            .accessibilityLabel(isCurrentMonth ? monthTitle : "\(monthTitle), \(text.backToThisMonth)")

            Button { onStepMonth?(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .accessibilityLabel(text.nextMonth)
        }
        .padding(.bottom, 2)
    }

    private func cell(for day: MonthDay) -> some View {
        Text("\(day.day)")
            .font(.caption)
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .foregroundStyle(foreground(for: day))
            .background(background(for: day), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                } else if day.override == .unpaidLeave {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                } else if day.isWorkday && !day.isPast {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // A half day is drawn as a corner wedge rather than a different colour, so
                // it stays readable on top of worked / upcoming / leave states.
                if day.isHalfDay {
                    Circle()
                        .fill(day.isPast && day.override == nil ? Color.white : Color.accentColor)
                        .frame(width: 4, height: 4)
                        .padding(2)
                }
            }
            // Without this a screen reader reads the grid as "1 2 3 4 …", which carries
            // none of what the colours are saying.
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func accessibilityLabel(for day: MonthDay) -> String {
        var parts = ["\(day.day)"]
        switch day.override {
        case .paidLeave: parts.append(text.legendPaidLeave)
        case .unpaidLeave: parts.append(text.legendUnpaidLeave)
        case .none:
            if day.isScheduled {
                parts.append(day.isPast ? text.legendWorked : text.legendUpcoming)
            } else {
                parts.append(text.dayOff)
            }
        }
        if day.isHalfDay { parts.append(text.halfDay) }
        if day.isToday { parts.append(text.today) }
        return parts.joined(separator: ", ")
    }

    private func foreground(for day: MonthDay) -> Color {
        switch day.override {
        case .paidLeave: return .orange
        case .unpaidLeave: return .secondary
        case .none: break
        }
        if day.isWorkday && day.isPast { return .white }
        if day.isWorkday { return .primary }
        return .secondary.opacity(0.6)
    }

    private func background(for day: MonthDay) -> Color {
        switch day.override {
        case .paidLeave: return .orange.opacity(0.18)
        case .unpaidLeave: return .secondary.opacity(0.08)
        case .none: break
        }
        if day.isWorkday && day.isPast { return .accentColor }
        if day.isWorkday { return .accentColor.opacity(0.10) }
        return .secondary.opacity(0.06)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                swatch(fill: .accentColor, label: text.legendWorked)
                swatch(fill: .accentColor.opacity(0.10), label: text.legendUpcoming, bordered: true)
                swatch(fill: .orange.opacity(0.18), label: text.legendPaidLeave)
                swatch(fill: .secondary.opacity(0.08), label: text.legendUnpaidLeave)
            }
            HStack {
                Text(text.workdaysDone(overview.completedWorkdayCount, overview.workdayCount))
                if overview.daysOffCount > 0 {
                    Text("· \(text.daysOff(overview.daysOffCount))")
                }
                Spacer()
            }
            .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func swatch(fill: Color, label: String, bordered: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .overlay {
                    if bordered {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                    }
                }
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}
