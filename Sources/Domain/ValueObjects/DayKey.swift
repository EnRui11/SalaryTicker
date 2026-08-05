import Foundation

/// A calendar day, independent of any instant inside it.
///
/// Stored as year/month/day rather than a `Date` because "the 5th of August" has to mean
/// the same square in the grid regardless of time zone, and because a `Date` would carry a
/// time that has no meaning here.
public struct DayKey: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// `2026-08-05` — the persisted form.
    public var raw: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public init?(raw: String) {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// What the user said about a specific day, overriding the weekly schedule.
public enum DayOverride: String, Hashable, CaseIterable, Sendable {
    /// A public holiday or paid annual leave: no work, but the day is still earned.
    case paidLeave
    /// No work and no pay — the month total loses a day.
    case unpaidLeave

    /// Cycles workday → paid → unpaid → workday, which is what a click on the grid does.
    public static func next(after current: DayOverride?) -> DayOverride? {
        switch current {
        case .none: .paidLeave
        case .paidLeave: .unpaidLeave
        case .unpaidLeave: nil
        }
    }

    /// Whether the day still contributes a full day's pay to the month.
    public var isPaid: Bool { self == .paidLeave }
}
