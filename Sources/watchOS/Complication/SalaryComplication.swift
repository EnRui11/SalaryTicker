import SwiftUI
import WidgetKit
import SalaryApplication
import SalaryCore
import SalaryDomain
import SalaryShared

/// The complication: the figure on the watch face, without opening anything.
///
/// It cannot tick. What it can do is hand WidgetKit a list of entries and the instant each
/// becomes current, and the system shows them with nothing running in between — which is
/// exactly what a calculator that is a pure function of `(config, now)` can produce.
///
/// Where the entries go is decided by `ComplicationTimeline`, which is in the application
/// layer and unit tested: dense while the shift is running, and otherwise the current value
/// plus the next moment it will change. That is the difference between a face that is right
/// all evening for two refreshes and one that burns a daily budget saying the same thing
/// sixty times.
struct SalaryProvider: TimelineProvider {
    private let container = AppContainer()

    func placeholder(in context: Context) -> SalaryEntry {
        SalaryEntry(date: Date(), earnings: .misconfigured, config: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
        let config = container.loadSettings()
        let now = Date()
        let entries = ComplicationTimeline.entries(
            config: config, from: now, covering: 3600, calendar: config.calendar()
        ).map { SalaryEntry(date: $0.date, earnings: $0.earnings, config: config) }

        // Ask to be rebuilt when the list runs out rather than on a fixed cadence: on a
        // Friday evening that is Monday morning, and there is nothing worth spending a
        // refresh on in between.
        let after = entries.last?.date ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(after)))
    }

    private func current() -> SalaryEntry {
        let config = container.loadSettings()
        let now = Date()
        return SalaryEntry(
            date: now,
            earnings: container.calculateEarnings(config: config, at: now),
            config: config
        )
    }
}

struct SalaryEntry: TimelineEntry {
    let date: Date
    let earnings: Earnings
    let config: SalaryConfig
}

struct SalaryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalaryEntry

    private var money: String {
        Formatting.money(entry.earnings.todayEarned, config: entry.config)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // A ring with the figure inside it. At this size the currency symbol and the
            // decimals are what get dropped first — the shape carries the day's progress.
            ZStack {
                ProgressView(value: clamped, total: 1) { EmptyView() }
                    .progressViewStyle(.circular)
                Text(Formatting.money(
                    entry.earnings.todayEarned, symbol: "",
                    digits: 0, language: entry.config.language
                ))
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .minimumScaleFactor(0.5)
            }
        case .accessoryInline:
            Text(money)
        default:
            HStack(spacing: 4) {
                Text(money)
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    private var clamped: Double {
        entry.earnings.progress.isFinite ? min(max(entry.earnings.progress, 0), 1) : 0
    }
}

@main
struct SalaryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.steve.salaryticker.complication", provider: SalaryProvider()) {
            SalaryComplicationView(entry: $0)
        }
        .configurationDisplayName("SalaryTicker")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}
