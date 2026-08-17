import Foundation
import SalaryDomain

/// The stretch of time a Live Activity can animate by itself.
///
/// A Live Activity cannot run code between updates. What it can do is be handed a date
/// range, and iOS will run a countdown and fill a progress bar across it with nothing
/// executing — which is the only thing on the Dynamic Island that moves without a server
/// pushing it. Working out the right range is arithmetic, so unlike the Dynamic Island
/// itself it can be tested.
public struct ShiftWindow: Equatable, Sendable {
    /// Clock-in. The bar fills from here, not from "now": handing it the remainder would
    /// restart it at zero every time the activity was updated.
    public let start: Date
    /// Clock-off.
    public let end: Date
    /// Whether the clock is inside it, which decides whether the phone shows a countdown to
    /// clock-off or a wait for the next shift.
    public let isRunning: Bool

    public init(start: Date, end: Date, isRunning: Bool) {
        self.start = start
        self.end = end
        self.isRunning = isRunning
    }

    /// The shift the given instant belongs to, or the next one if it is between shifts.
    ///
    /// Nil when the schedule earns nothing at all, in which case there is no range to
    /// animate and the activity has nothing to say.
    public static func current(
        config: SalaryConfig,
        at now: Date,
        calendar: Calendar = .current,
        horizonDays: Int = 14
    ) -> ShiftWindow? {
        guard config.isValid else { return nil }

        if let today = config.workingWindow(on: now, calendar: calendar),
           now < today.end, today.end > today.start {
            return ShiftWindow(start: today.start, end: today.end, isRunning: now >= today.start)
        }

        var cursor = now
        for _ in 0...horizonDays {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: cursor),
                  tomorrow > cursor
            else { return nil }
            cursor = calendar.startOfDay(for: tomorrow)

            if let next = config.workingWindow(on: cursor, calendar: calendar), next.end > next.start {
                return ShiftWindow(start: next.start, end: next.end, isRunning: false)
            }
        }
        return nil
    }
}
