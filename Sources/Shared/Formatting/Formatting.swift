import Foundation
import SalaryDomain

/// What the status item should draw.
public enum MenuBarContent: Equatable, Sendable {
    case text(String)
    /// Nothing worth showing right now — draw the icon and give the space back.
    case icon
}

/// Display formatting. Lives in Shared so it can be unit tested without launching the UI.
public enum Formatting {

    // MARK: Money

    public static func money(_ amount: Double, config: SalaryConfig) -> String {
        money(amount, symbol: config.currencySymbol, digits: config.fractionDigits,
              language: config.language)
    }

    /// `$1,234.57` / `1.234,57 $` — grouping and the decimal separator follow the
    /// language's locale, and the symbol goes where that language puts it.
    ///
    /// The app speaks nine languages; leaving the number itself in English formatting was
    /// the kind of mismatch you feel without being able to name it.
    public static func money(
        _ amount: Double,
        symbol: String,
        digits: Int,
        language: AppLanguage
    ) -> String {
        let safe = amount.isFinite ? amount : 0
        let places = min(max(digits, 0), 6)
        let number = safe.formatted(
            .number
                .precision(.fractionLength(places))
                .grouping(.automatic)
                .locale(locale(for: language))
        )
        guard !symbol.isEmpty else { return number }
        // Non-breaking space: a trailing symbol must never wrap away from its number.
        return language.currencySymbolLeads ? symbol + number : number + "\u{00A0}" + symbol
    }

    // MARK: Durations

    /// `2h 13m` / `13m 20s` / `45s`, in the configured language.
    public static func duration(_ seconds: TimeInterval, _ strings: Strings) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 { return strings.hoursMinutes(hours, minutes) }
        if minutes > 0 { return strings.minutesSeconds(minutes, secs) }
        return strings.seconds(secs)
    }

    // MARK: Status

    /// The short line shown next to the number inside the panel.
    public static func statusText(_ status: WorkStatus, _ strings: Strings) -> String {
        switch status {
        case .dayOff: strings.dayOff
        case .beforeWork(let startsIn): strings.startsIn(duration(startsIn, strings))
        case .working(let endsIn): strings.untilClockOff(duration(endsIn, strings))
        case .lunch(let endsIn): strings.lunchLeft(duration(endsIn, strings))
        case .afterWork: strings.clockedOff
        case .overtime(let elapsed): strings.overtimeFor(duration(elapsed, strings))
        case .misconfigured: strings.setupIncomplete
        }
    }

    /// `August 2026`, or its equivalent in whichever language is configured.
    ///
    /// - Parameter timeZone: the zone the schedule is read in, which is not always this
    ///   Mac's. Half past midnight on 1 September in Kuala Lumpur is still August in New
    ///   York, and the grid must agree with the calculator about which month it is showing.
    public static func monthTitle(
        _ date: Date, language: AppLanguage, timeZone: TimeZone = .current
    ) -> String {
        // Starting from a preset would drag the day number in with it.
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale(for: language))
            .year()
            .month(.wide)
        style.timeZone = timeZone
        return style.format(date)
    }

    /// `Thu 6 Aug, 18:00` — enough to act on, short enough for a panel row.
    ///
    /// - Parameter timeZone: as above. A projection computed for six in the evening in the
    ///   configured zone has to be shown as six in the evening, not translated back into
    ///   whatever zone the Mac happens to be sitting in.
    public static func readyTimestamp(
        _ date: Date, language: AppLanguage, timeZone: TimeZone = .current
    ) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale(for: language))
            .weekday(.abbreviated)
            .day()
            .month(.abbreviated)
            .hour()
            .minute()
        style.timeZone = timeZone
        return style.format(date)
    }

    /// `2.1` — one decimal, because "two and a bit days" is the resolution anyone acts on.
    public static func workdays(_ value: Double, language: AppLanguage) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return safe.formatted(.number.precision(.fractionLength(1)).locale(locale(for: language)))
    }

    // MARK: Menu bar

    /// What the menu bar itself shows. Non-working states deliberately avoid a
    /// ticking number so a frozen value never looks like a hung app.
    public static func menuBarContent(_ earnings: Earnings, config: SalaryConfig) -> MenuBarContent {
        let strings = Strings(config.language)

        if config.menuBarIconOnlyWhenIdle && !earnings.status.isAccruing {
            return .icon
        }

        return switch earnings.status {
        case .misconfigured: .text(strings.menuBarSetSalary)
        case .dayOff: .text(strings.menuBarDayOff)
        case .beforeWork: .text(menuBarMoney(0, config: config))
        default: .text(menuBarMoney(earnings.todayEarned, config: config))
        }
    }

    /// String form, for the settings preview and tests.
    public static func menuBarText(_ earnings: Earnings, config: SalaryConfig) -> String {
        switch menuBarContent(earnings, config: config) {
        case .text(let value): value
        case .icon: ""
        }
    }

    private static func menuBarMoney(_ amount: Double, config: SalaryConfig) -> String {
        money(
            amount,
            symbol: config.menuBarShowsCurrencySymbol ? config.currencySymbol : "",
            digits: config.fractionDigits,
            language: config.language
        )
    }

    // MARK: Locale

    /// Built once: the menu bar reformats every second, and `Locale` construction is not free.
    private static let locales: [AppLanguage: Locale] = Dictionary(
        uniqueKeysWithValues: AppLanguage.allCases.map { ($0, Locale(identifier: $0.localeIdentifier)) }
    )

    static func locale(for language: AppLanguage) -> Locale {
        locales[language] ?? .current
    }
}
