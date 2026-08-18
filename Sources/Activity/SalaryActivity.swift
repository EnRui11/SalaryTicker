import Foundation
// os(iOS) rather than canImport: the module exists on macOS, and ActivityAttributes
// inside it does not, so the import succeeds and the conformance fails.
#if os(iOS)
import ActivityKit
#endif

/// Where a tap on the Dynamic Island goes.
///
/// iOS reserves the tap on a Live Activity for launching the app and gives no way to ask
/// for anything else — the expanded preview is reached by touch-and-hold, and there is no
/// API to open it in code. What a tap CAN be told is where to land, and without this it
/// lands wherever the app happened to be left, which after a visit to Settings is a
/// half-scrolled sheet rather than the number the island was showing.
///
/// Declared here because this module is the one both the app and the widget extension can
/// see, so the two cannot drift into disagreeing about the address.
public enum SalaryActivityLink {
    public static let host = "today"
    /// A literal that cannot fail to parse; the fallback exists only to avoid a `!`.
    public static let url = URL(string: "salaryticker://\(host)") ?? URL(fileURLWithPath: "/")
}

/// What the Live Activity carries.
///
/// Split the way the platform forces it to be split, which happens to be the honest split
/// anyway. The dates are fixed for the whole shift and iOS animates a countdown and a
/// progress bar across them with nothing running — those are live and exact. The money is a
/// snapshot, because updating it needs either the app in the foreground or a push server,
/// and this app has neither. It is labelled as of a time for that reason.
#if os(iOS)
public struct SalaryActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable, Sendable {
        /// Clock-in and clock-off. The system animates between them by itself.
        public var shiftStart: Date
        public var shiftEnd: Date
        /// Inside the shift, or waiting for the next one.
        public var isRunning: Bool
        /// Earned so far, as of `asOf`. Frozen until something updates it.
        public var earned: Double
        public var asOf: Date
        /// Formatting, carried along so the extension does not need the settings store.
        public var currencySymbol: String
        public var fractionDigits: Int

        public init(
            shiftStart: Date, shiftEnd: Date, isRunning: Bool,
            earned: Double, asOf: Date,
            currencySymbol: String, fractionDigits: Int
        ) {
            self.shiftStart = shiftStart
            self.shiftEnd = shiftEnd
            self.isRunning = isRunning
            self.earned = earned
            self.asOf = asOf
            self.currencySymbol = currencySymbol
            self.fractionDigits = fractionDigits
        }

        /// A range the system will always accept. An empty or inverted one crashes the
        /// timer views rather than drawing nothing.
        public var animatableRange: ClosedRange<Date> {
            shiftEnd > shiftStart ? shiftStart...shiftEnd : shiftStart...shiftStart.addingTimeInterval(1)
        }
    }

    public init() {}
}
#endif
