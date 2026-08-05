import Foundation

/// Everything the user can configure.
///
/// A domain value object: no `Codable`, no knowledge of where it is stored. Persistence
/// lives in the data layer as `SalaryConfigDTO`.
public struct SalaryConfig: Equatable, Sendable {
    /// Gross monthly salary, in whatever currency `currencySymbol` denotes.
    public var monthlySalary: Double
    public var workStart: TimeOfDay
    public var workEnd: TimeOfDay
    /// When enabled, the lunch window is unpaid and excluded from the daily total.
    public var lunchEnabled: Bool
    public var lunchStart: TimeOfDay
    public var lunchEnd: TimeOfDay
    /// Working days as `Calendar` weekday numbers (1 = Sunday ... 7 = Saturday).
    public var workdays: Set<Int>
    /// Weekdays worked at half length — a Saturday morning, typically. Must also appear
    /// in `workdays`; anything else here is ignored.
    public var halfDays: Set<Int>
    public var currencySymbol: String
    public var fractionDigits: Int
    public var language: AppLanguage
    /// IANA identifier the schedule is read in, or nil to follow this Mac's clock.
    ///
    /// Only matters when the two disagree — someone whose hours belong to an office in
    /// another country, or who travels. The stored value is the identifier rather than an
    /// offset so the zone keeps its own daylight saving rules.
    public var timeZoneIdentifier: String?
    /// Days the user marked as holiday or leave, overriding the weekly schedule.
    ///
    /// The two kinds differ in where they land:
    /// - **Paid** leave leaves the divisor. You are paid the same monthly salary for fewer
    ///   days of work, so the days you do work are each worth more — the holiday's share is
    ///   absorbed by them rather than paid out on the day itself.
    /// - **Unpaid** leave stays in the divisor and pays nothing, which is exactly how you
    ///   end the month one day's pay short.
    public var dayOverrides: [DayKey: DayOverride]
    /// Things the user is saving for, priced in working time.
    public var goals: [SavingsGoal]
    /// Draw today's progress as a small ring in the menu bar.
    ///
    /// The app icon cannot do this — the app has no Dock tile to update, and rewriting the
    /// bundle's own icon would break its signature to change a Finder window nobody is
    /// looking at. The status item is where a live indicator belongs.
    public var menuBarShowsProgressRing: Bool
    /// Show the currency symbol in the menu bar. Off buys back a character of width.
    public var menuBarShowsCurrencySymbol: Bool
    /// Outside working hours, collapse the status item to a small icon.
    public var menuBarIconOnlyWhenIdle: Bool
    /// Keep counting after clock-off.
    ///
    /// The app cannot know when you actually stopped, so overtime is capped rather than
    /// left to run all night — without the cap you would wake up to six invented hours.
    public var overtimeEnabled: Bool
    /// Multiplier applied to the normal per-second rate during overtime.
    public var overtimeMultiplier: Double
    /// How long overtime may accrue after clock-off before it stops.
    public var overtimeMaxHours: Int
    /// Whether the user asked the app to start at login.
    ///
    /// Stored rather than read back from the system, because macOS reports menu bar apps
    /// as enabled login items merely for having run once. This is the answer the toggle
    /// shows; the system is reconciled to it at launch.
    public var launchAtLoginEnabled: Bool

    public init(
        monthlySalary: Double = 10_000,
        workStart: TimeOfDay = TimeOfDay(9, 0),
        workEnd: TimeOfDay = TimeOfDay(18, 0),
        lunchEnabled: Bool = true,
        lunchStart: TimeOfDay = TimeOfDay(12, 0),
        lunchEnd: TimeOfDay = TimeOfDay(13, 0),
        workdays: Set<Int> = [2, 3, 4, 5, 6],
        halfDays: Set<Int> = [],
        currencySymbol: String = "$",
        fractionDigits: Int = 4,
        language: AppLanguage = .english,
        timeZoneIdentifier: String? = nil,
        dayOverrides: [DayKey: DayOverride] = [:],
        goals: [SavingsGoal] = [],
        menuBarShowsProgressRing: Bool = true,
        menuBarShowsCurrencySymbol: Bool = true,
        menuBarIconOnlyWhenIdle: Bool = false,
        overtimeEnabled: Bool = false,
        overtimeMultiplier: Double = 1.0,
        overtimeMaxHours: Int = 4,
        launchAtLoginEnabled: Bool = false
    ) {
        self.monthlySalary = monthlySalary
        self.workStart = workStart
        self.workEnd = workEnd
        self.lunchEnabled = lunchEnabled
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        self.workdays = workdays
        self.halfDays = halfDays
        self.currencySymbol = currencySymbol
        self.fractionDigits = fractionDigits
        self.language = language
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayOverrides = dayOverrides
        self.goals = goals
        self.menuBarShowsProgressRing = menuBarShowsProgressRing
        self.menuBarShowsCurrencySymbol = menuBarShowsCurrencySymbol
        self.menuBarIconOnlyWhenIdle = menuBarIconOnlyWhenIdle
        self.overtimeEnabled = overtimeEnabled
        self.overtimeMultiplier = overtimeMultiplier
        self.overtimeMaxHours = overtimeMaxHours
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    public static let `default` = SalaryConfig()

    /// The calendar the schedule should be read in.
    ///
    /// An identifier that no longer exists in the system's zone database falls back to
    /// this Mac's clock rather than to UTC, which would silently shift the whole day.
    public func calendar(basedOn base: Calendar = .current) -> Calendar {
        guard let identifier = timeZoneIdentifier,
              let zone = TimeZone(identifier: identifier)
        else { return base }

        var calendar = base
        calendar.timeZone = zone
        return calendar
    }
}

// MARK: - Derived values

extension SalaryConfig {
    /// Unpaid lunch minutes that actually fall inside the working window.
    /// A lunch break configured outside working hours deducts nothing.
    public var unpaidLunchMinutes: Int {
        guard lunchEnabled else { return 0 }
        return Self.overlapMinutes(
            workStart.minutesFromMidnight, workEnd.minutesFromMidnight,
            lunchStart.minutesFromMidnight, lunchEnd.minutesFromMidnight
        )
    }

    /// Paid minutes in a full working day, lunch excluded.
    ///
    /// Deliberately computed from the schedule instead of a separate
    /// "hours per day" field, so the two can never contradict each other.
    public var dailyPaidMinutes: Int {
        let span = workEnd.minutesFromMidnight - workStart.minutesFromMidnight
        guard span > 0 else { return 0 }
        return max(0, span - unpaidLunchMinutes)
    }

    public var dailyPaidSeconds: TimeInterval { TimeInterval(dailyPaidMinutes * 60) }

    /// Seconds of overtime that may accrue in a day, clamped to something sane.
    public var overtimeCapSeconds: TimeInterval {
        guard overtimeEnabled else { return 0 }
        return TimeInterval(min(max(overtimeMaxHours, 0), 12) * 3600)
    }

    /// Multiplier actually applied, guarded against a nonsense value in the field.
    public var effectiveOvertimeMultiplier: Double {
        guard overtimeMultiplier.isFinite, overtimeMultiplier > 0 else { return 0 }
        return min(overtimeMultiplier, 10)
    }

    /// How much of a normal day the weekly schedule puts on this weekday: 1, ½, or none.
    ///
    /// Everything downstream — the divisor, the length of the working window, what a
    /// finished day contributes to the month — is this one number, so a half day can never
    /// mean one thing to the clock and another to the wallet.
    public func scheduledWeight(forWeekday weekday: Int) -> Double {
        guard workdays.contains(weekday) else { return 0 }
        return halfDays.contains(weekday) ? 0.5 : 1
    }

    public func scheduledWeight(for date: Date, calendar: Calendar = .current) -> Double {
        scheduledWeight(forWeekday: calendar.component(.weekday, from: date))
    }

    /// What the day actually pays out. Any kind of day off pays nothing on the day
    /// itself; a paid one is already reflected in the higher rate of every working day.
    public func payWeight(for date: Date, calendar: Calendar = .current) -> Double {
        guard dayOverrides[DayKey(date, calendar: calendar)] == nil else { return 0 }
        return scheduledWeight(for: date, calendar: calendar)
    }

    /// The share of the month this day carries in the divisor.
    /// Paid leave carries none — that is what makes the other days worth more.
    public func divisorWeight(for date: Date, calendar: Calendar = .current) -> Double {
        guard dayOverrides[DayKey(date, calendar: calendar)] != .paidLeave else { return 0 }
        return scheduledWeight(for: date, calendar: calendar)
    }

    /// Everything the month sweep produces, gathered in one pass.
    public struct MonthTotals: Equatable, Sendable {
        /// The divisor: scheduled days, a half day counting a half.
        public var equivalents: Double
        /// What the days before today are worth in pay, halves and leave accounted for.
        public var paidWeightBeforeToday: Double
        /// Days with any work scheduled, halves counted as whole days.
        public var workdayCount: Int
        public var completedWorkdayCount: Int
        public var daysOffCount: Int
    }

    /// One pass over the month, producing every figure the ticker needs.
    ///
    /// `equivalents` is the divisor: scheduled weight minus paid leave. `paidWeightBeforeToday`
    /// is what the finished days actually paid, which excludes every kind of day off.
    ///
    /// Deliberately not seven separate helpers: each of those walked all 31 days building
    /// `DateComponents`, and calling them once per second each turned a menu bar app into
    /// a measurable CPU load.
    public func monthTotals(for date: Date, calendar: Calendar = .current) -> MonthTotals {
        var totals = MonthTotals(
            equivalents: 0, paidWeightBeforeToday: 0,
            workdayCount: 0, completedWorkdayCount: 0, daysOffCount: 0
        )
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let year = parts.year, let month = parts.month, let today = parts.day,
              let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else { return totals }

        for dayOfMonth in range {
            guard let day = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstOfMonth)
            else { continue }

            let weight = scheduledWeight(forWeekday: calendar.component(.weekday, from: day))
            guard weight > 0 else { continue }

            // The key is built from the loop counters rather than re-derived from the
            // date, which saves a `dateComponents` call per day.
            let override = dayOverrides[DayKey(year: year, month: month, day: dayOfMonth)]

            let divisorWeight = (override == .paidLeave) ? 0 : weight
            totals.equivalents += divisorWeight
            if divisorWeight > 0 { totals.workdayCount += 1 }
            if override != nil { totals.daysOffCount += 1 }
            if dayOfMonth < today {
                if divisorWeight > 0 { totals.completedWorkdayCount += 1 }
                totals.paidWeightBeforeToday += (override == nil) ? weight : 0
            }
        }
        return totals
    }

    /// Days worked in the month containing `date`, counting a half day as a half.
    ///
    /// This is the divisor. It is a real count rather than a monthly average, so the daily
    /// rate moves with the month, and the month always totals exactly `monthlySalary`.
    /// Leave never enters it: taking a day off must not make every other day worth more.
    public func workdayEquivalentsInMonth(of date: Date, calendar: Calendar = .current) -> Double {
        sumOverMonth(of: date, calendar: calendar) { day in
            divisorWeight(for: day, calendar: calendar)
        }
    }

    /// Count of days that carry pay this month, halves included as whole days.
    public func workdaysInMonth(of date: Date, calendar: Calendar = .current) -> Int {
        Int(sumOverMonth(of: date, calendar: calendar) { day in
            divisorWeight(for: day, calendar: calendar) > 0 ? 1 : 0
        })
    }

    private func sumOverMonth(
        of date: Date,
        calendar: Calendar,
        _ value: (Date) -> Double
    ) -> Double {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return 0 }

        return range.reduce(into: 0.0) { total, dayOfMonth in
            guard let day = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstOfMonth)
            else { return }
            total += value(day)
        }
    }

    private func sumBeforeToday(
        _ date: Date,
        calendar: Calendar,
        _ value: (Date) -> Double
    ) -> Double {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return 0 }

        let today = calendar.component(.day, from: date)
        return range.prefix(max(0, today - 1)).reduce(into: 0.0) { total, dayOfMonth in
            guard let day = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstOfMonth)
            else { return }
            total += value(day)
        }
    }

    /// Scheduled working days of this month already finished — strictly before `date`'s
    /// day. Today is excluded because it is still being earned. Leave is still counted
    /// here: this is "days that have gone by", not "days that paid".
    public func completedWorkdaysInMonth(before date: Date, calendar: Calendar = .current) -> Int {
        Int(sumBeforeToday(date, calendar: calendar) { day in
            divisorWeight(for: day, calendar: calendar) > 0 ? 1 : 0
        })
    }

    /// What the finished days of this month are worth, in whole-day equivalents.
    /// Half days count a half; unpaid leave counts nothing; paid leave counts in full.
    public func paidWeightCompletedInMonth(before date: Date, calendar: Calendar = .current) -> Double {
        sumBeforeToday(date, calendar: calendar) { day in
            payWeight(for: day, calendar: calendar)
        }
    }

    /// Days this month marked as holiday or leave that fall on a scheduled workday.
    public func daysOffInMonth(of date: Date, calendar: Calendar = .current) -> Int {
        Int(sumOverMonth(of: date, calendar: calendar) { day in
            guard scheduledWeight(for: day, calendar: calendar) > 0,
                  dayOverrides[DayKey(day, calendar: calendar)] != nil
            else { return 0 }
            return 1
        })
    }

    /// Pay for one FULL working day in the month containing `date`.
    /// A half day earns half of this.
    ///
    /// Marking days as paid leave raises this, because the same salary now covers fewer
    /// working days. A month where every scheduled day is a paid holiday has nothing left
    /// to absorb the pay, so it falls back to the full schedule rather than dividing by zero.
    public func dailyPay(at date: Date, calendar: Calendar = .current) -> Double {
        var equivalents = workdayEquivalentsInMonth(of: date, calendar: calendar)
        if equivalents <= 0 {
            equivalents = sumOverMonth(of: date, calendar: calendar) { day in
                scheduledWeight(for: day, calendar: calendar)
            }
        }
        guard equivalents > 0 else { return 0 }
        return monthlySalary / equivalents
    }

    /// When this day starts and ends, and whether lunch comes out of it.
    ///
    /// A half day runs from clock-in for half the paid minutes and skips lunch entirely —
    /// a Saturday morning does not stop for it. Nil when the day is not worked at all.
    public func workingWindow(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date, deductsLunch: Bool)? {
        let seconds = paidSeconds(on: date, calendar: calendar)
        guard seconds > 0 else { return nil }

        let start = workStart.resolved(on: date, calendar: calendar)

        if scheduledWeight(for: date, calendar: calendar) < 1 {
            return (start, start.addingTimeInterval(seconds), false)
        }

        let end = workEnd.resolved(on: date, calendar: calendar)
        guard end > start else { return nil }
        return (start, end, lunchEnabled)
    }

    /// Paid seconds in this particular day's window — halved on a half day, zero when the
    /// day is marked as leave.
    public func paidSeconds(on date: Date, calendar: Calendar = .current) -> TimeInterval {
        guard dayOverrides[DayKey(date, calendar: calendar)] == nil else { return 0 }
        return dailyPaidSeconds * scheduledWeight(for: date, calendar: calendar)
    }

    public func ratePerSecond(at date: Date, calendar: Calendar = .current) -> Double {
        guard dailyPaidSeconds > 0 else { return 0 }
        return dailyPay(at: date, calendar: calendar) / dailyPaidSeconds
    }

    public func hourlyPay(at date: Date, calendar: Calendar = .current) -> Double {
        ratePerSecond(at: date, calendar: calendar) * 3600
    }

    /// False when the schedule cannot produce a meaningful rate — the UI surfaces this
    /// rather than letting a divide-by-zero reach the menu bar as `NaN`.
    public var isValid: Bool {
        // `.isFinite` matters: the salary field accepts "1e400" and "∞", and an
        // infinite salary would turn into NaN the moment zero seconds have elapsed.
        monthlySalary > 0 && monthlySalary.isFinite && dailyPaidMinutes > 0 && !workdays.isEmpty
    }

    /// Whether this specific date is a day the user actually works.
    ///
    /// A day marked as holiday or leave is not, whichever way the weekly schedule reads.
    public func isWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        isScheduledWorkday(date, calendar: calendar)
            && dayOverrides[DayKey(date, calendar: calendar)] == nil
    }

    /// Whether the weekly schedule alone puts work on this date, ignoring overrides.
    /// This is what the monthly divisor counts.
    public func isScheduledWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        workdays.contains(calendar.component(.weekday, from: date))
    }

    static func overlapMinutes(_ aStart: Int, _ aEnd: Int, _ bStart: Int, _ bEnd: Int) -> Int {
        max(0, min(aEnd, bEnd) - max(aStart, bStart))
    }
}
