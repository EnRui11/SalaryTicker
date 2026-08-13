import Foundation
import SalaryDomain

/// What a watch complication should show over the next stretch of time, worked out in
/// advance.
///
/// A complication cannot run code every second. What it can do is be handed a list of
/// entries with the instant each one becomes current, and display them without waking
/// anything — which is precisely what a calculator that is a pure function of
/// `(config, now)` can produce. Nothing here needs a background task, a server, or a push.
///
/// The design question is *where* to put the entries, and a fixed one a minute is wrong in
/// both directions. All evening the figure has not moved since clock-off, so sixty
/// identical entries spend a refresh budget the system counts in tens per day. And it says
/// nothing about the one instant that matters, which is the second the next shift starts.
/// So: step through time that is being paid for, and otherwise emit the current value and
/// the next moment it will change.
public enum ComplicationTimeline {

    public struct Entry: Sendable {
        /// When this entry becomes the one on the face.
        public let date: Date
        public let earnings: Earnings

        public init(date: Date, earnings: Earnings) {
            self.date = date
            self.earnings = earnings
        }
    }

    /// A ceiling on the list, so asking for a long window cannot return thousands.
    public static let maximumEntries = 120

    /// How far ahead to look for the next shift when the current one is over.
    private static let horizonDays = 14

    public static func entries(
        config: SalaryConfig,
        from now: Date,
        covering span: TimeInterval = 3600,
        step: TimeInterval = 60,
        calendar: Calendar = .current
    ) -> [Entry] {
        let snapshot = { (date: Date) in
            Entry(
                date: date,
                earnings: EarningsCalculator.earnings(config: config, at: date, calendar: calendar)
            )
        }

        let current = snapshot(now)
        guard config.isValid else { return [current] }

        // Inside a shift the number moves, so walk it. Lunch counts as inside: the figure
        // holds still for an hour, but the afternoon is minutes away rather than tomorrow,
        // and going to sleep through it would leave the face stale when it resumes.
        if isWithinShift(config: config, at: now, calendar: calendar) {
            var entries = [current]
            var cursor = now
            let end = now.addingTimeInterval(span)

            while cursor < end, entries.count < maximumEntries {
                cursor = cursor.addingTimeInterval(step)
                entries.append(snapshot(cursor))
            }
            return entries
        }

        // Otherwise the figure is frozen — before work, after clock-off, a day off. One
        // entry says what it is, and one more says when it will next be worth looking at.
        guard let next = nextShiftStart(config: config, after: now, calendar: calendar) else {
            return [current]
        }
        return [current, snapshot(next)]
    }

    /// Between clock-in and clock-off on a day that pays, lunch included.
    private static func isWithinShift(
        config: SalaryConfig, at instant: Date, calendar: Calendar
    ) -> Bool {
        guard let window = config.workingWindow(on: instant, calendar: calendar) else { return false }
        return instant >= window.start && instant < window.end
    }

    /// The next instant the number starts moving again.
    ///
    /// Today's own start counts when it has not arrived yet, which is what makes the
    /// morning-before-work case point at nine o'clock rather than at tomorrow.
    private static func nextShiftStart(
        config: SalaryConfig, after instant: Date, calendar: Calendar
    ) -> Date? {
        var cursor = instant
        for _ in 0...horizonDays {
            if let window = config.workingWindow(on: cursor, calendar: calendar), window.start > instant {
                return window.start
            }
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: cursor),
                  tomorrow > cursor
            else { return nil }
            cursor = calendar.startOfDay(for: tomorrow)
        }
        return nil
    }
}
