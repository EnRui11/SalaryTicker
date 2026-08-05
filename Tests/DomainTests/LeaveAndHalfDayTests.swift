import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 1st is a Saturday, the 5th a Wednesday, the 31st a Monday.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

private func key(_ day: Int) -> DayKey { DayKey(year: 2026, month: 8, day: day) }

private let standard = SalaryConfig(monthlySalary: 10_000)   // Mon–Fri, 09:00–18:00, 1h lunch
private func hours(_ n: Double) -> TimeInterval { n * 3600 }

// MARK: - DayKey

@Test func dayKeyRoundTripsThroughItsStoredForm() {
    let original = DayKey(year: 2026, month: 8, day: 5)
    #expect(original.raw == "2026-08-05")
    #expect(DayKey(raw: "2026-08-05") == original)
}

@Test(arguments: ["", "2026-08", "2026-13-01", "2026-08-40", "not-a-date", "2026/08/05"])
func aMalformedDayKeyIsRejectedRatherThanGuessed(raw: String) {
    #expect(DayKey(raw: raw) == nil)
}

@Test func theClickCycleReturnsToWorking() {
    #expect(DayOverride.next(after: nil) == .paidLeave)
    #expect(DayOverride.next(after: .paidLeave) == .unpaidLeave)
    #expect(DayOverride.next(after: .unpaidLeave) == nil)
}

// MARK: - Leave

@Test func paidLeaveLeavesTheDivisorSoTheWorkingDaysPayMore() {
    // The same monthly salary now covers one fewer working day.
    var holiday = standard
    holiday.dayOverrides = [key(3): .paidLeave]

    let now = at(14, 0)
    #expect(holiday.workdayEquivalentsInMonth(of: now, calendar: cal()) == 20)
    #expect(standard.workdayEquivalentsInMonth(of: now, calendar: cal()) == 21)
    #expect(holiday.dailyPay(at: now, calendar: cal()) == 10_000.0 / 20)
    #expect(holiday.dailyPay(at: now, calendar: cal())
            > standard.dailyPay(at: now, calendar: cal()))
}

@Test func unpaidLeaveStaysInTheDivisorSoTheMonthComesUpShort() {
    // Keeping it in the divisor is exactly what makes the day's pay disappear instead of
    // being redistributed to the other days.
    var unpaid = standard
    unpaid.dayOverrides = [key(3): .unpaidLeave]

    let now = at(14, 0)
    #expect(unpaid.workdayEquivalentsInMonth(of: now, calendar: cal())
            == standard.workdayEquivalentsInMonth(of: now, calendar: cal()))
    #expect(unpaid.dailyPay(at: now, calendar: cal()) == standard.dailyPay(at: now, calendar: cal()))
}

@Test func aDayMarkedOffDoesNotTick() {
    var today = standard
    today.dayOverrides = [key(5): .paidLeave]
    let result = EarningsCalculator.earnings(config: today, at: at(14, 0), calendar: cal())

    #expect(result.todayEarned == 0)
    #expect(result.elapsedPaidSeconds == 0)
    #expect(result.status == .dayOff)
}

@Test func aFullyWorkedMonthWithPaidHolidaysStillTotalsTheSalary() {
    // The holiday pays nothing on the day; its share rides on every other working day, so
    // the month still lands exactly on the salary.
    var holidays = standard
    holidays.dayOverrides = [key(3): .paidLeave, key(17): .paidLeave]

    let endOfMonth = at(23, 0, day: 31)
    let result = EarningsCalculator.earnings(config: holidays, at: endOfMonth, calendar: cal())
    #expect(abs(result.monthEarned - 10_000) < 1e-9)
    #expect(result.daysOffThisMonth == 2)
    #expect(result.workdaysThisMonth == 19)
}

@Test func markingAPastDayAsPaidLeaveMovesItsPayIntoTheRemainingDays() {
    // A consequence of the chosen model, pinned so it is a decision and not a surprise:
    // month-to-date drops when a finished day becomes a paid holiday, because that day's
    // share now has to be earned on the days still ahead.
    var holiday = standard
    holiday.dayOverrides = [key(3): .paidLeave]

    let now = at(14, 0)
    let before = EarningsCalculator.earnings(config: standard, at: now, calendar: cal())
    let after = EarningsCalculator.earnings(config: holiday, at: now, calendar: cal())

    #expect(after.monthEarned < before.monthEarned)
    #expect(after.dailyPay > before.dailyPay)
}

@Test func unpaidLeaveCostsExactlyOneDaysPayOverTheMonth() {
    var unpaid = standard
    unpaid.dayOverrides = [key(3): .unpaidLeave]

    let endOfMonth = at(23, 0, day: 31)
    let result = EarningsCalculator.earnings(config: unpaid, at: endOfMonth, calendar: cal())
    #expect(abs(result.monthEarned - (10_000 - result.dailyPay)) < 1e-9)
}

@Test func leaveOnAWeekendIsIgnored() {
    // The 8th is a Saturday and already not worked; marking it must change nothing.
    var odd = standard
    odd.dayOverrides = [key(8): .unpaidLeave]

    let now = at(14, 0)
    #expect(EarningsCalculator.earnings(config: odd, at: now, calendar: cal())
            == EarningsCalculator.earnings(config: standard, at: now, calendar: cal()))
}

@Test func aMonthWithNoWorkingDaysLeftDoesNotDivideByZero() {
    // Degenerate: every scheduled day marked as a paid holiday leaves nothing to absorb
    // the salary. It must not produce NaN or an infinite rate.
    var allOff = standard
    let overview = standard.monthOverview(for: at(12, 0, day: 31), now: at(12, 0, day: 31), calendar: cal())
    allOff.dayOverrides = Dictionary(
        uniqueKeysWithValues: overview.days.filter(\.isScheduled).map { ($0.key, DayOverride.paidLeave) }
    )
    let result = EarningsCalculator.earnings(config: allOff, at: at(23, 0, day: 31), calendar: cal())
    #expect(result.monthEarned.isFinite)
    #expect(result.dailyPay.isFinite)
    #expect(result.ratePerSecond.isFinite)
    #expect(result.monthEarned >= 0)
}

// MARK: - Half days

@Test func aHalfDayCountsAsHalfInTheDivisor() {
    var withSaturday = standard
    withSaturday.workdays.insert(7)          // Saturday
    withSaturday.halfDays.insert(7)

    let now = at(14, 0)
    // August 2026 has 5 Saturdays and 21 Mon–Fri days.
    #expect(withSaturday.workdayEquivalentsInMonth(of: now, calendar: cal()) == 21 + 5 * 0.5)
    #expect(withSaturday.workdaysInMonth(of: now, calendar: cal()) == 26)
}

@Test func aHalfDayRunsHalfAsLongAndSkipsLunch() {
    var withSaturday = standard
    withSaturday.workdays.insert(7)
    withSaturday.halfDays.insert(7)

    // Saturday the 8th: 8 paid hours halved is 4, running 09:00–13:00 with no lunch break.
    #expect(withSaturday.paidSeconds(on: at(12, 0, day: 8), calendar: cal()) == hours(4))

    let midMorning = EarningsCalculator.earnings(config: withSaturday, at: at(11, 0, day: 8), calendar: cal())
    #expect(midMorning.elapsedPaidSeconds == hours(2))
    #expect(midMorning.status == .working(endsIn: hours(2)))

    // Noon would be lunch on a full day; on a half day it is simply still working.
    let noon = EarningsCalculator.earnings(config: withSaturday, at: at(12, 30, day: 8), calendar: cal())
    #expect(noon.elapsedPaidSeconds == hours(3.5))

    let afterwards = EarningsCalculator.earnings(config: withSaturday, at: at(15, 0, day: 8), calendar: cal())
    #expect(afterwards.elapsedPaidSeconds == hours(4))
    #expect(afterwards.status == .afterWork)
}

@Test func aHalfDayEarnsExactlyHalfADaysPay() {
    var withSaturday = standard
    withSaturday.workdays.insert(7)
    withSaturday.halfDays.insert(7)

    let saturday = at(23, 0, day: 8)
    let result = EarningsCalculator.earnings(config: withSaturday, at: saturday, calendar: cal())
    #expect(abs(result.todayEarned - result.dailyPay / 2) < 1e-9)
}

@Test func aScheduleWithHalfDaysStillTotalsTheMonthlySalary() {
    var withSaturday = standard
    withSaturday.workdays.insert(7)
    withSaturday.halfDays.insert(7)

    // 2026-08-31 is the last day of the month and a full Monday: after clock-off the whole
    // month is behind us.
    let result = EarningsCalculator.earnings(config: withSaturday, at: at(23, 0, day: 31), calendar: cal())
    #expect(abs(result.monthEarned - 10_000) < 1e-9)
}

@Test func markingAHalfDayAsLeaveOnlyCostsHalf() {
    var withSaturday = standard
    withSaturday.workdays.insert(7)
    withSaturday.halfDays.insert(7)

    var unpaidSaturday = withSaturday
    unpaidSaturday.dayOverrides = [key(1): .unpaidLeave]      // Saturday the 1st, a half day

    let endOfMonth = at(23, 0, day: 31)
    let result = EarningsCalculator.earnings(config: unpaidSaturday, at: endOfMonth, calendar: cal())
    #expect(abs(result.monthEarned - (10_000 - result.dailyPay / 2)) < 1e-9)
}

@Test func aHalfDayWeekdayNotInWorkdaysIsIgnored() {
    var stray = standard
    stray.halfDays = [1, 7]                 // weekend, but neither is a workday
    let now = at(14, 0)
    #expect(stray.workdayEquivalentsInMonth(of: now, calendar: cal())
            == standard.workdayEquivalentsInMonth(of: now, calendar: cal()))
}

@Test func theGridReportsHalfDaysAndLeave() {
    var mixed = standard
    mixed.workdays.insert(7)
    mixed.halfDays.insert(7)
    mixed.dayOverrides = [key(3): .paidLeave]

    let overview = mixed.monthOverview(for: at(12, 0), now: at(12, 0), calendar: cal())
    let saturdayFirst = overview.days[0]
    #expect(saturdayFirst.isHalfDay)
    #expect(saturdayFirst.isWorkday)

    let third = overview.days[2]
    #expect(third.override == .paidLeave)
    #expect(third.isWorkday == false)
    #expect(overview.daysOffCount == 1)
}

@Test(arguments: [DayOverride.paidLeave, .unpaidLeave])
func aDayOffFallingTodayPaysNothingToday(kind: DayOverride) {
    var today = standard
    today.dayOverrides = [key(5): kind]

    let result = EarningsCalculator.earnings(config: today, at: at(14, 0), calendar: cal())
    #expect(result.todayEarned == 0)
    // Only the 3rd and 4th are behind us, and both were worked.
    #expect(abs(result.monthEarned - 2 * result.dailyPay) < 1e-9)
}

@Test func theMonthTotalNeverExceedsTheSalaryWithAnyMixOfLeaveAndHalfDays() {
    var mixed = standard
    mixed.workdays.insert(7)
    mixed.halfDays.insert(7)
    mixed.dayOverrides = [
        key(3): .paidLeave, key(4): .unpaidLeave, key(1): .paidLeave, key(17): .unpaidLeave,
    ]

    for day in 1...31 {
        for hour in [0, 9, 13, 18, 23] {
            let result = EarningsCalculator.earnings(config: mixed, at: at(hour, 0, day: day), calendar: cal())
            #expect(result.monthEarned >= 0)
            #expect(result.monthEarned <= 10_000 + 1e-9, "day \(day) hour \(hour)")
            #expect(result.monthEarned.isFinite)
        }
    }
}

@Test func theSingleMonthSweepAgreesWithTheIndividualHelpers() {
    // `earnings` derives everything from one pass now; if that pass ever drifts from the
    // named helpers the panel and the settings page start telling different stories.
    var mixed = standard
    mixed.workdays.insert(7)
    mixed.halfDays.insert(7)
    mixed.dayOverrides = [key(3): .paidLeave, key(4): .unpaidLeave, key(15): .paidLeave]

    for day in [1, 5, 17, 31] {
        let now = at(14, 0, day: day)
        let totals = mixed.monthTotals(for: now, calendar: cal())

        #expect(totals.equivalents == mixed.workdayEquivalentsInMonth(of: now, calendar: cal()))
        #expect(totals.workdayCount == mixed.workdaysInMonth(of: now, calendar: cal()))
        #expect(totals.completedWorkdayCount
                == mixed.completedWorkdaysInMonth(before: now, calendar: cal()))
        #expect(totals.daysOffCount == mixed.daysOffInMonth(of: now, calendar: cal()))
        #expect(abs(totals.paidWeightBeforeToday
                    - mixed.paidWeightCompletedInMonth(before: now, calendar: cal())) < 1e-9)
    }
}

@Test func theGridCountsAgreeWithTheNumbersInSettings() {
    // The legend under the calendar and the "Workdays this month" row are two renderings
    // of the same figure; letting them drift is how a UI starts contradicting itself.
    var mixed = standard
    mixed.workdays.insert(7)
    mixed.halfDays.insert(7)
    mixed.dayOverrides = [key(3): .paidLeave, key(4): .unpaidLeave]

    for day in [1, 5, 17, 31] {
        let now = at(14, 0, day: day)
        let overview = mixed.monthOverview(for: now, now: now, calendar: cal())
        let earnings = EarningsCalculator.earnings(config: mixed, at: now, calendar: cal())

        #expect(overview.workdayCount == earnings.workdaysThisMonth)
        #expect(overview.completedWorkdayCount == earnings.workdaysCompletedThisMonth)
        #expect(overview.daysOffCount == earnings.daysOffThisMonth)
    }
}
