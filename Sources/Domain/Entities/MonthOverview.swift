import Foundation

/// One square in the month grid.
public struct MonthDay: Equatable, Sendable {
    public let key: DayKey
    public let day: Int
    /// `Calendar` weekday number, 1 = Sunday.
    public let weekday: Int
    /// How much of a normal day the weekly schedule puts here: 1, ½, or 0.
    public let scheduledWeight: Double
    /// Whether the weekly schedule puts any work here, before any override.
    public var isScheduled: Bool { scheduledWeight > 0 }
    public var isHalfDay: Bool { scheduledWeight > 0 && scheduledWeight < 1 }
    /// Holiday or leave the user marked on this day, if any.
    public let override: DayOverride?
    /// Scheduled and not overridden — a day that actually earns.
    public var isWorkday: Bool { isScheduled && override == nil }
    public let isToday: Bool
    /// Strictly before today — already earned, if it was a workday.
    public let isPast: Bool

    public init(
        key: DayKey, day: Int, weekday: Int, scheduledWeight: Double,
        override: DayOverride?, isToday: Bool, isPast: Bool
    ) {
        self.key = key
        self.day = day
        self.weekday = weekday
        self.scheduledWeight = scheduledWeight
        self.override = override
        self.isToday = isToday
        self.isPast = isPast
    }
}

/// The current month laid out for display, Sunday-first.
public struct MonthOverview: Equatable, Sendable {
    /// Empty cells before the 1st, so the grid lines up under the weekday headings.
    public let leadingBlanks: Int
    public let days: [MonthDay]
    /// Days that carry pay — the same count the divisor uses, so the grid and the
    /// settings page can never disagree. Paid holidays are not among them.
    public let workdayCount: Int
    public let completedWorkdayCount: Int
    public let daysOffCount: Int

    public init(
        leadingBlanks: Int, days: [MonthDay],
        workdayCount: Int, completedWorkdayCount: Int, daysOffCount: Int = 0
    ) {
        self.leadingBlanks = leadingBlanks
        self.days = days
        self.workdayCount = workdayCount
        self.completedWorkdayCount = completedWorkdayCount
        self.daysOffCount = daysOffCount
    }

    public static let empty = MonthOverview(
        leadingBlanks: 0, days: [], workdayCount: 0, completedWorkdayCount: 0
    )
}

extension SalaryConfig {
    /// Builds the month grid for the month containing `month`.
    ///
    /// `now` is separate because the grid can be browsed: looking at September must not
    /// make the 5th of September "today" just because today is the 5th of August. Past and
    /// present are decided against the real date, not against a day number.
    ///
    /// Lives in the domain rather than the view so the calendar arithmetic — leading
    /// blanks, month length, which squares count as worked — can be tested without
    /// rendering anything.
    public func monthOverview(
        for month: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthOverview {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return .empty }

        let todayKey = DayKey(now, calendar: calendar)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        var days: [MonthDay] = []
        var workdayCount = 0
        var completedCount = 0
        var daysOff = 0

        for dayOfMonth in range {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstOfMonth)
            else { continue }

            let weekday = calendar.component(.weekday, from: dayDate)
            let weight = scheduledWeight(forWeekday: weekday)
            let isScheduled = weight > 0
            let key = DayKey(dayDate, calendar: calendar)
            let override = isScheduled ? dayOverrides[key] : nil
            let isPast = key < todayKey

            if isScheduled {
                if override != .paidLeave {
                    workdayCount += 1
                    if isPast { completedCount += 1 }
                }
                if override != nil { daysOff += 1 }
            }

            days.append(
                MonthDay(
                    key: key,
                    day: dayOfMonth,
                    weekday: weekday,
                    scheduledWeight: weight,
                    override: override,
                    isToday: key == todayKey,
                    isPast: isPast
                )
            )
        }

        return MonthOverview(
            // Sunday-first, matching the weekday headings and `Calendar`'s numbering.
            leadingBlanks: firstWeekday - 1,
            days: days,
            workdayCount: workdayCount,
            completedWorkdayCount: completedCount,
            daysOffCount: daysOff
        )
    }
}
