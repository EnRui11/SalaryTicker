import Foundation

/// A wall-clock time of day, independent of any particular date.
///
/// Stored as hour/minute rather than a `Date` so that the schedule means the same
/// thing every day regardless of time zone changes or daylight saving transitions.
public struct TimeOfDay: Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int) {
        self.hour = Self.clamp(hour, 0, 23)
        self.minute = Self.clamp(minute, 0, 59)
    }

    /// Minutes elapsed since midnight. Used for all schedule arithmetic.
    public var minutesFromMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }
}

extension TimeOfDay {
    /// Resolves this time of day onto a concrete calendar day.
    ///
    /// Uses `Calendar` rather than adding seconds to midnight so that daylight
    /// saving transitions produce the correct wall-clock instant.
    ///
    /// Resolves to the first wall-clock time at or after this one that actually exists on
    /// `day`, and the result is always on `day`.
    ///
    /// Both halves of that sentence are load-bearing, because `date(bySettingHour:)` is
    /// not trustworthy on a daylight-saving transition day. Asked for a time the gap
    /// swallowed, it may return the *next day* (America/Nuuk loses 23:00 on 2026-03-28),
    /// return nil, or — worst, because it looks correct — return a same-day instant whose
    /// clock reads something else entirely: in Pacific/Chatham it answers 03:04 with
    /// 04:00, which is later than its answer for 03:54.
    ///
    /// So every candidate is read back and verified. An exhaustive sweep of every IANA
    /// zone across a year is what surfaced this; without the read-back, `resolved` is not
    /// monotonic and workStart can land after workEnd — the inversion this method exists
    /// to prevent.
    ///
    /// The loop only ever iterates on a transition day, and only across the gap.
    public func resolved(on day: Date, calendar: Calendar) -> Date {
        var probe = minutesFromMidnight
        while probe < 24 * 60 {
            if let exact = Self.instant(hour: probe / 60, minute: probe % 60, on: day, calendar: calendar) {
                return exact
            }
            probe += 1
        }

        // The gap runs to midnight, so the last instant of the day is the latest one there is.
        let startOfDay = calendar.startOfDay(for: day)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return startOfDay
        }
        return startOfNextDay.addingTimeInterval(-1)
    }

    /// The instant on `day` whose clock reads exactly `hour:minute`, or nil if that time
    /// does not occur on that day.
    private static func instant(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date? {
        guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              calendar.isDate(candidate, inSameDayAs: day)
        else { return nil }

        let parts = calendar.dateComponents([.hour, .minute], from: candidate)
        guard parts.hour == hour, parts.minute == minute else { return nil }
        return candidate
    }

    /// Builds a `TimeOfDay` from the hour/minute components of a `Date`.
    public init(from date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(parts.hour ?? 0, parts.minute ?? 0)
    }

    /// A `Date` carrying only these hour/minute components, for binding to `DatePicker`.
    ///
    /// Anchored on today rather than the 1970 epoch: zones that ran odd historical
    /// offsets (Africa/Monrovia was UTC−00:44:30 until 1972) have no instant matching
    /// most hour/minute pairs back then, which used to collapse every non-round time
    /// in Settings to 00:00.
    public func asPickerDate(calendar: Calendar = .current, now: Date = Date()) -> Date {
        resolved(on: calendar.startOfDay(for: now), calendar: calendar)
    }
}
