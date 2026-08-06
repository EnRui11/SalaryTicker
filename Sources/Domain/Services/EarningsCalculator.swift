import Foundation

/// Stateless earnings math — a pure domain service.
///
/// Every value is derived from `(config, now)` — nothing is accumulated between ticks.
/// That is what makes the display survive sleep, quit/relaunch, and clock changes:
/// there is no running total to drift out of sync.
public enum EarningsCalculator {

    /// - Parameter monthTotals: the month sweep, when the caller already has one for this
    ///   config and day. It only changes at midnight or when settings change, so a ticking
    ///   UI should hand the same one back every second rather than pay for it 60 times a
    ///   minute.
    public static func earnings(
        config: SalaryConfig,
        at now: Date,
        monthTotals: SalaryConfig.MonthTotals? = nil,
        calendar: Calendar = .current
    ) -> Earnings {
        guard config.isValid else { return .misconfigured }

        let total = config.paidSeconds(on: now, calendar: calendar)
        // One sweep of the month, reused for the rate, the divisor and every count below.
        let totals = monthTotals ?? config.monthTotals(for: now, calendar: calendar)
        let dailyPay = config.dailyPay(at: now, calendar: calendar)
        let rate = config.dailyPaidSeconds > 0 ? dailyPay / config.dailyPaidSeconds : 0
        let isWorkday = config.isWorkday(now, calendar: calendar)

        let elapsed = isWorkday
            ? paidSecondsAccrued(config: config, on: now, upTo: now, calendar: calendar)
            : 0
        // A multiplier that cannot pay — zero, negative, not a number — means there is no
        // overtime, not unpaid overtime. Counting the seconds anyway put "Overtime for
        // 1h 20m" in the status line beside a figure that had not moved since clock-off.
        let overtime = isWorkday && config.effectiveOvertimeMultiplier > 0
            ? overtimeSecondsAccrued(config: config, on: now, upTo: now, calendar: calendar)
            : 0
        let overtimeEarned = overtime * rate * config.effectiveOvertimeMultiplier
        let todayEarned = elapsed * rate + overtimeEarned
        // Unpaid leave is the only thing that removes a finished day from the month total;
        // a paid holiday still earns even though nothing ticked that day.
        let paidWeight = totals.paidWeightBeforeToday

        return Earnings(
            todayEarned: todayEarned,
            dailyPay: dailyPay,
            hourlyPay: rate * 3600,
            ratePerSecond: rate,
            overtimeSeconds: overtime,
            overtimeEarned: overtimeEarned,
            // Finished days pay their weight; today pays whatever has accrued. A day off
            // pays nothing on the day itself — a paid one was already absorbed into the
            // higher rate every working day of the month carries.
            monthEarned: paidWeight * dailyPay + todayEarned,
            workdaysThisMonth: totals.workdayCount,
            workdaysCompletedThisMonth: totals.completedWorkdayCount,
            daysOffThisMonth: totals.daysOffCount,
            elapsedPaidSeconds: elapsed,
            totalPaidSeconds: total,
            progress: total > 0 ? elapsed / total : 0,
            status: status(
                config: config, at: now, isWorkday: isWorkday,
                overtimeSeconds: overtime, calendar: calendar
            )
        )
    }

    /// Paid seconds accrued on `day`'s working window, from its start up to `instant`.
    ///
    /// Saturating at both ends: an instant before the window returns 0, one after it
    /// returns a full day. That saturation is what makes the number freeze by itself
    /// outside working hours — no timer needs to be stopped, and nothing needs resetting
    /// at midnight, because tomorrow simply asks about tomorrow's window.
    public static func paidSecondsAccrued(
        config: SalaryConfig,
        on day: Date,
        upTo instant: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let window = config.workingWindow(on: day, calendar: calendar)
        guard let window else { return 0 }

        let cursor = min(max(instant, window.start), window.end)
        var seconds = cursor.timeIntervalSince(window.start)

        if window.deductsLunch {
            let lunchStart = config.lunchStart.resolved(on: day, calendar: calendar)
            let lunchEnd = config.lunchEnd.resolved(on: day, calendar: calendar)
            seconds -= overlapSeconds(window.start, cursor, lunchStart, lunchEnd)
        }

        // Clamped against this day's nominal total so a DST jump can never pay out
        // more than the day is worth.
        return min(max(seconds, 0), config.paidSeconds(on: day, calendar: calendar))
    }

    /// Seconds worked past clock-off today, capped by the configured maximum.
    ///
    /// Capped rather than open-ended because the app has no idea when you actually left:
    /// without a ceiling, a Mac left on overnight would invent a full evening of pay.
    public static func overtimeSecondsAccrued(
        config: SalaryConfig,
        on day: Date,
        upTo instant: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        guard config.overtimeEnabled, config.overtimeCapSeconds > 0 else { return 0 }

        guard let window = config.workingWindow(on: day, calendar: calendar) else { return 0 }
        let end = window.end
        guard instant > end else { return 0 }

        // Never spills into tomorrow, so the number still resets by itself at midnight.
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? instant
        let cursor = min(instant, endOfDay)

        return min(max(cursor.timeIntervalSince(end), 0), config.overtimeCapSeconds)
    }

    static func status(
        config: SalaryConfig,
        at now: Date,
        isWorkday: Bool,
        overtimeSeconds: TimeInterval,
        calendar: Calendar
    ) -> WorkStatus {
        guard isWorkday else { return .dayOff }

        guard let window = config.workingWindow(on: now, calendar: calendar) else { return .dayOff }
        let start = window.start
        let end = window.end

        if now < start { return .beforeWork(startsIn: start.timeIntervalSince(now)) }
        if now >= end {
            return overtimeSeconds > 0 ? .overtime(elapsed: overtimeSeconds) : .afterWork
        }

        if window.deductsLunch {
            let lunchStart = config.lunchStart.resolved(on: now, calendar: calendar)
            let lunchEnd = config.lunchEnd.resolved(on: now, calendar: calendar)
            if now >= lunchStart && now < lunchEnd {
                return .lunch(endsIn: lunchEnd.timeIntervalSince(now))
            }
        }
        return .working(endsIn: end.timeIntervalSince(now))
    }

    static func overlapSeconds(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> TimeInterval {
        max(0, min(aEnd, bEnd).timeIntervalSince(max(aStart, bStart)))
    }
}
