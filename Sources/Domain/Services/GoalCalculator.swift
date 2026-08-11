import Foundation

/// Turns a price into working time, and into the day you will actually have the money.
public enum GoalCalculator {

    /// How far ahead the projection is willing to walk before giving up.
    ///
    /// A cap is needed because a large enough goal against a small enough salary never
    /// arrives, and a loop looking for it would not stop.
    static let horizonDays = 366 * 5

    /// Slack for the comparison that decides whether a day finishes the goal.
    ///
    /// `amount / rate` does not land on a whole number of seconds — a goal worth exactly
    /// three days comes out as 86400.000000000015 — and subtracting whole days leaves that
    /// crumb behind. Without the tolerance the crumb fails the "does today finish it" test
    /// and the answer slides to the next working day, which over a weekend is a three-day
    /// error on the most ordinary case there is.
    private static let secondsTolerance: TimeInterval = 0.001

    /// - Parameter earnedBeforeToday: everything banked before today, when the caller
    ///   already has it. It only changes at midnight, so a ticking UI should hand the same
    ///   figure back every second rather than walk the calendar again for it.
    public static func projection(
        for goal: SavingsGoal,
        config: SalaryConfig,
        now: Date,
        earnedBeforeToday: Double? = nil,
        calendar: Calendar = .current
    ) -> GoalProjection {
        projections(
            for: [goal], config: config, now: now,
            bankedSinceStart: earnedBeforeToday.map { [goal.startedAt: $0] },
            calendar: calendar
        ).first ?? .unreachable
    }

    // MARK: - A list of goals is not a set of independent ones

    /// Projections for a whole list, funded in the order the list is in.
    ///
    /// This has to be a list operation. A ringgit can only be spent once, and the previous
    /// per-goal version let every goal count all the money earned since it began: with
    /// $3,333 in hand, two $3,000 goals both read 100% and the app said you could afford
    /// both. Priority is the list's own order — first in the list is first to be paid.
    ///
    /// - Parameter bankedSinceStart: everything earned before today, per start instant,
    ///   when the caller already has it. That is the expensive half and it only changes at
    ///   midnight, so a ticking UI hands the same figures back every second.
    public static func projections(
        for goals: [SavingsGoal],
        config: SalaryConfig,
        now: Date,
        bankedSinceStart: [Date: Double]? = nil,
        calendar: Calendar = .current
    ) -> [GoalProjection] {
        let rate = config.ratePerSecond(at: now, calendar: calendar)
        let funded = fundedAmounts(
            for: goals, config: config, now: now,
            bankedSinceStart: bankedSinceStart, calendar: calendar
        )

        // Each goal's date is the date the queue reaches the end of it, so a goal waits for
        // everything above it before its own price starts being paid off.
        var shortfallAhead = 0.0
        return goals.map { goal in
            guard goal.isValid, config.isValid, rate > 0, rate.isFinite else { return .unreachable }

            let workSeconds = goal.amount / rate
            let earned = min(funded[goal.id] ?? 0, goal.amount)
            shortfallAhead += max(0, goal.amount - earned)

            return GoalProjection(
                // The price in work is the goal's own. Waiting your turn does not make a
                // thing cost more of your life, it only moves the day you get it.
                workSeconds: workSeconds,
                workdays: config.dailyPaidSeconds > 0 ? workSeconds / config.dailyPaidSeconds : 0,
                earned: earned,
                progress: goal.amount > 0 ? min(max(earned / goal.amount, 0), 1) : 0,
                readyAt: readyDate(
                    needing: shortfallAhead, config: config, now: now, calendar: calendar
                )
            )
        }
    }

    /// How much of what has been earned belongs to each goal.
    ///
    /// Allocated chronologically, not just by rank: money earned at some moment goes to the
    /// highest-priority goal that *had already been created by then* and is not yet full.
    /// Ranking alone would let a goal added today reach back and take a month of earnings
    /// away from an older one that had already been paid with it.
    ///
    /// The walk is over the instants goals joined the queue, because between two of those
    /// the set of claimants cannot change.
    static func fundedAmounts(
        for goals: [SavingsGoal],
        config: SalaryConfig,
        now: Date,
        bankedSinceStart: [Date: Double]?,
        calendar: Calendar
    ) -> [SavingsGoal.ID: Double] {
        let queue = goals.filter { $0.isValid && $0.startedAt < now }
        guard !queue.isEmpty, config.isValid else { return [:] }

        // Everything still to come at the moment each goal joined. Computed once per
        // distinct instant, so goals created in the same click share one walk.
        var earnedSince: [Date: Double] = [:]
        for start in Set(queue.map(\.startedAt)) {
            let banked = bankedSinceStart?[start]
                ?? earnedBeforeToday(since: start, config: config, now: now, calendar: calendar)
            earnedSince[start] = banked
                + earnedToday(since: start, config: config, now: now, calendar: calendar)
        }

        let boundaries = earnedSince.keys.sorted()
        var funded: [SavingsGoal.ID: Double] = [:]
        var remaining = Dictionary(uniqueKeysWithValues: queue.map { ($0.id, $0.amount) })

        for (index, from) in boundaries.enumerated() {
            // What was earned between this boundary and the next, or between it and now.
            let stillToCome = index + 1 < boundaries.count
                ? (earnedSince[boundaries[index + 1]] ?? 0)
                : 0
            var pot = max(0, (earnedSince[from] ?? 0) - stillToCome)
            guard pot > 0 else { continue }

            for goal in queue where goal.startedAt <= from {
                let need = remaining[goal.id] ?? 0
                guard need > 0 else { continue }
                let take = min(pot, need)
                funded[goal.id, default: 0] += take
                remaining[goal.id] = need - take
                pot -= take
                if pot <= 0 { break }
            }
        }
        return funded
    }

    /// Everything earned towards the goal since saving for it began.
    ///
    /// Derived rather than stored, for the same reason nothing else in this app
    /// accumulates: a counter drifts across sleep, relaunch and clock changes, whereas a
    /// figure recomputed from `(schedule, startedAt, now)` cannot.
    public static func earned(
        for goal: SavingsGoal,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        earnedBeforeToday(for: goal, config: config, now: now, calendar: calendar)
            + earnedToday(for: goal, config: config, now: now, calendar: calendar)
    }

    /// Everything banked towards the goal before today began.
    ///
    /// The expensive half — it walks every day since saving started — and the half that
    /// only changes at midnight, which is why it is separable at all.
    public static func earnedBeforeToday(
        for goal: SavingsGoal,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        earnedBeforeToday(since: goal.startedAt, config: config, now: now, calendar: calendar)
    }

    /// As above, from a bare instant. The walks never needed a goal, only the moment
    /// counting started, and the allocator asks about moments that belong to no goal.
    public static func earnedBeforeToday(
        since start: Date,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        guard now > start else { return 0 }

        let firstDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        // Saving started today, so nothing is banked yet; it is all in today's total.
        guard firstDay < today else { return 0 }

        // The first day counts only from the moment saving began; the rest count in full.
        var total = paid(
            on: start,
            between: start,
            and: endOfDay(start, calendar: calendar),
            config: config, calendar: calendar
        )

        var cursor = calendar.date(byAdding: .day, value: 1, to: firstDay) ?? today
        while cursor < today {
            total += config.payWeight(for: cursor, calendar: calendar)
                * config.dailyPay(at: cursor, calendar: calendar)
            // Bounded by the calendar rather than by a horizon. The forward walk needs a
            // cap because an unaffordable goal never arrives; the past has a definite
            // length and every day of it was really paid, so capping it here only made an
            // old goal stop counting. What can actually go wrong is arithmetic that fails
            // to advance, so that is what this guards.
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor
            else { break }
            cursor = next
        }
        return total
    }

    /// Today's contribution: the day's earnings, less anything earned before the goal
    /// existed.
    ///
    /// The cheap half — a handful of calendar operations, safe to run on every tick. The
    /// subtraction is what stops a goal added at five in the afternoon from arriving
    /// already paid for out of the morning's work.
    public static func earnedToday(
        for goal: SavingsGoal,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        earnedToday(since: goal.startedAt, config: config, now: now, calendar: calendar)
    }

    public static func earnedToday(
        since start: Date,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        guard now > start else { return 0 }

        let today = calendar.startOfDay(for: now)
        // Includes overtime, which `paidSecondsAccrued` alone would miss.
        var total = EarningsCalculator.earnings(config: config, at: now, calendar: calendar).todayEarned

        if start > today {
            total -= paid(
                on: now, between: today, and: start, config: config, calendar: calendar
            )
            // Overtime needs its own term. `paid` is built on `paidSecondsAccrued`, which
            // saturates at the end of the working window and so cannot see a single second
            // past clock-off — while `total` above already contains all of them. Without
            // this, a goal created in the evening is born funded by the overtime that was
            // already on the clock, which is precisely what `startedAt` exists to prevent.
            total -= overtimePay(
                on: now, upTo: start, config: config, calendar: calendar
            )
        }
        return max(0, total)
    }

    /// Overtime money earned on `day` up to `instant`, priced at the multiplier.
    private static func overtimePay(
        on day: Date,
        upTo instant: Date,
        config: SalaryConfig,
        calendar: Calendar
    ) -> Double {
        EarningsCalculator.overtimeSecondsAccrued(
            config: config, on: day, upTo: instant, calendar: calendar
        ) * config.ratePerSecond(at: day, calendar: calendar) * config.effectiveOvertimeMultiplier
    }

    /// Money earned on one day between two instants of it.
    private static func paid(
        on day: Date,
        between start: Date,
        and end: Date,
        config: SalaryConfig,
        calendar: Calendar
    ) -> Double {
        let from = EarningsCalculator.paidSecondsAccrued(config: config, on: day, upTo: start, calendar: calendar)
        let to = EarningsCalculator.paidSecondsAccrued(config: config, on: day, upTo: end, calendar: calendar)
        return max(0, to - from) * config.ratePerSecond(at: day, calendar: calendar)
    }

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return (calendar.date(byAdding: .day, value: 1, to: start) ?? date).addingTimeInterval(-1)
    }

    /// Walks the schedule forward until enough has been earned.
    ///
    /// Counts *future* pay only, which is what gives the answer its useful property: while
    /// you are working, the money and the clock advance together and the date barely moves;
    /// while you are not, it slips away from you.
    ///
    /// The walk carries money rather than paid seconds, and that is not a detail. A paid
    /// second is worth a different amount in every month, because the daily rate is the
    /// salary divided by *that* month's working days — 21 in August 2026, 22 in September,
    /// 20 in February 2027. Converting the shortfall to seconds once, at today's rate, and
    /// then spending those seconds in a month where they buy something else lands the goal
    /// on the wrong day. `earnedBeforeToday` has always priced each past day in its own
    /// month; this is the same arithmetic pointed forwards.
    ///
    /// The walk is day by day rather than closed-form because days are not interchangeable —
    /// weekends, half days, leave and the month they fall in all make a different amount.
    static func readyDate(
        needing amount: Double,
        config: SalaryConfig,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard amount > 0 else { return now }

        var remaining = amount
        var cursor = now

        for dayIndex in 0..<horizonDays {
            // Today counts only from this instant; every later day counts in full.
            let dayStart = dayIndex == 0
                ? now
                : calendar.startOfDay(for: cursor)

            guard let window = config.workingWindow(on: cursor, calendar: calendar) else {
                cursor = nextDay(after: cursor, calendar: calendar) ?? cursor
                continue
            }

            let from = max(dayStart, window.start)
            let alreadyDone = EarningsCalculator.paidSecondsAccrued(
                config: config, on: cursor, upTo: from, calendar: calendar
            )
            let wholeDay = config.paidSeconds(on: cursor, calendar: calendar)
            let availableToday = max(0, wholeDay - alreadyDone)
            // What this particular day is worth, which is the whole point of the walk.
            let rate = config.ratePerSecond(at: cursor, calendar: calendar)
            guard rate > 0, rate.isFinite else {
                cursor = nextDay(after: cursor, calendar: calendar) ?? cursor
                continue
            }
            let earnableToday = availableToday * rate

            if remaining <= earnableToday + secondsTolerance * rate {
                return instant(
                    afterAccruing: alreadyDone + remaining / rate,
                    on: cursor, config: config, calendar: calendar
                )
            }

            remaining -= earnableToday
            cursor = nextDay(after: cursor, calendar: calendar) ?? cursor
        }
        return nil
    }

    /// The moment on `day` at which `paidSeconds` of its window have been worked.
    ///
    /// Steps over the unpaid lunch break rather than through it, so a goal that lands at
    /// "four paid hours in" on a 09:00 day reports 14:00, not 13:00.
    private static func instant(
        afterAccruing paidSeconds: TimeInterval,
        on day: Date,
        config: SalaryConfig,
        calendar: Calendar
    ) -> Date? {
        guard let window = config.workingWindow(on: day, calendar: calendar) else { return nil }

        var candidate = window.start.addingTimeInterval(paidSeconds)
        if window.deductsLunch {
            let lunchStart = config.lunchStart.resolved(on: day, calendar: calendar)
            let lunchEnd = config.lunchEnd.resolved(on: day, calendar: calendar)
            if candidate > lunchStart {
                candidate = candidate.addingTimeInterval(lunchEnd.timeIntervalSince(lunchStart))
            }
        }
        return min(candidate, window.end)
    }

    private static func nextDay(after date: Date, calendar: Calendar) -> Date? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return calendar.startOfDay(for: tomorrow)
    }
}
