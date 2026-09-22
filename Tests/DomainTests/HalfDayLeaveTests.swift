import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: Mon–Fri gives 21 working days. The 5th is a Wednesday, the 8th a Saturday.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

private func key(_ day: Int) -> DayKey { DayKey(year: 2026, month: 8, day: day) }

/// $4,000 basic plus a $1,000 allowance. 09:00–18:00 with an unpaid 12:00–13:00 lunch, so
/// eight paid hours and a half day of four.
private func split(_ overrides: [DayKey: DayOverride] = [:]) -> SalaryConfig {
    var config = SalaryConfig(monthlySalary: 4_000)
    config.monthlyAllowance = 1_000
    config.dayOverrides = overrides
    return config
}

private func earnings(_ config: SalaryConfig, _ instant: Date) -> Earnings {
    EarningsCalculator.earnings(config: config, at: instant, calendar: cal())
}

private func monthTotal(_ config: SalaryConfig) -> Double {
    earnings(config, at(23, 0, day: 31)).monthEarned
}

private let hour: TimeInterval = 3_600

// MARK: - The money
//
// A half day of unpaid leave is half of a day of unpaid leave, and nothing about that is
// new: the basic loses half a day, the allowance loses nothing. The two halves differ only
// in when the day is worked, never in what it pays.

@Test func aHalfDayOffCostsHalfADayOfBasicAndNoneOfTheAllowance() {
    let withHalf = monthTotal(split([key(7): .unpaidAfternoon]))
    #expect(abs(withHalf - (5_000 - 4_000.0 / 21 / 2)) < 1e-6)
}

@Test func theMorningAndTheAfternoonCostExactlyTheSame() {
    let morning = monthTotal(split([key(7): .unpaidMorning]))
    let afternoon = monthTotal(split([key(7): .unpaidAfternoon]))
    #expect(abs(morning - afternoon) < 1e-9)
}

@Test func twoHalfDaysOffCostTheSameAsOneWholeDayOff() {
    // The strongest check on the algebra: if the halves were weighted even slightly off,
    // two of them would stop adding up to one.
    let twoHalves = monthTotal(split([key(7): .unpaidMorning, key(12): .unpaidAfternoon]))
    let oneWhole = monthTotal(split([key(7): .unpaidLeave]))
    #expect(abs(twoHalves - oneWhole) < 1e-6)
}

@Test func aHalfDayOffStaysInTheBasicsDivisor() {
    // Unpaid leave is a day that was owed and not worked, so it stays in the divisor. If a
    // half day came out of it, every other day would quietly be worth more and the half
    // day would cost less than it should.
    let totals = split([key(7): .unpaidMorning]).monthTotals(for: at(10), calendar: cal())
    #expect(totals.equivalents == 21)
    #expect(totals.earningWeight == 20.5)
}

// MARK: - When the day is worked

@Test func anAfternoonOffTicksInTheMorningAndStopsAtOne() {
    let config = split([key(5): .unpaidAfternoon])

    #expect(earnings(config, at(8, 59)).elapsedPaidSeconds == 0)
    #expect(earnings(config, at(11)).elapsedPaidSeconds == 2 * hour)
    // A half day does not stop for lunch, which is what makes it four hours from nine.
    #expect(earnings(config, at(12, 30)).elapsedPaidSeconds == 3.5 * hour)
    #expect(earnings(config, at(13)).elapsedPaidSeconds == 4 * hour)
    #expect(earnings(config, at(16)).elapsedPaidSeconds == 4 * hour)
}

@Test func aMorningOffWaitsUntilTwoAndEndsAtClockOff() {
    let config = split([key(5): .unpaidMorning])

    // The whole reason there are two kinds: at eleven this person is not at work, and a
    // single "half day" that assumed the morning would already be two hours in.
    let eleven = earnings(config, at(11))
    #expect(eleven.elapsedPaidSeconds == 0)
    guard case .beforeWork(let startsIn) = eleven.status else {
        Issue.record("expected beforeWork, got \(eleven.status)"); return
    }
    #expect(startsIn == 3 * hour)

    #expect(earnings(config, at(16)).elapsedPaidSeconds == 2 * hour)
    #expect(earnings(config, at(18)).elapsedPaidSeconds == 4 * hour)
}

@Test func eitherHalfEarnsHalfTheDaysPayByTheEndOfIt() {
    for half in [DayOverride.unpaidMorning, .unpaidAfternoon] {
        let e = earnings(split([key(5): half]), at(23))
        #expect(abs(e.todayEarned - e.dailyPay / 2) < 1e-9, "\(half)")
        #expect(e.progress == 1, "\(half)")
    }
}

@Test func aHalfDayOfLeaveIsStillAWorkdayAndAWholeOneIsNot() {
    // Before half days, "workday" meant "no override", and under that rule the half that
    // is worked would never have ticked at all.
    #expect(split([key(5): .unpaidMorning]).isWorkday(at(15), calendar: cal()))
    #expect(split([key(5): .unpaidAfternoon]).isWorkday(at(10), calendar: cal()))
    #expect(!split([key(5): .unpaidLeave]).isWorkday(at(10), calendar: cal()))
}

// MARK: - Overtime

private func withOvertime(_ overrides: [DayKey: DayOverride]) -> SalaryConfig {
    var config = split(overrides)
    config.overtimeEnabled = true
    config.overtimeMultiplier = 1.5
    config.overtimeMaxHours = 4
    return config
}

@Test func anAfternoonOffNeverStartsOvertime() {
    // Overtime is counted from the end of the window, and on an afternoon off the window
    // ends at one. Without a rule against it, three o'clock on an afternoon of unpaid leave
    // would read as two hours of overtime — pay for the very hours taken off.
    let e = earnings(withOvertime([key(5): .unpaidAfternoon]), at(15))
    #expect(e.overtimeSeconds == 0)
    #expect(e.overtimeEarned == 0)
    guard case .afterWork = e.status else {
        Issue.record("expected afterWork, got \(e.status)"); return
    }
}

@Test func aMorningOffCanStillRunLate() {
    // The mirror case is allowed on purpose: someone who came in for the afternoon can
    // stay past clock-off like on any other day.
    let e = earnings(withOvertime([key(5): .unpaidMorning]), at(19))
    #expect(e.overtimeSeconds == hour)
}

// MARK: - A half day of leave on a day that is already a half day

private func withSaturdayMornings(_ overrides: [DayKey: DayOverride] = [:]) -> SalaryConfig {
    var config = split(overrides)
    config.workdays.insert(7)
    config.halfDays = [7]
    return config
}

@Test func aSaturdayHalfDayRunsNineToOne() {
    let window = withSaturdayMornings().workingWindow(on: at(10, day: 8), calendar: cal())
    #expect(window?.start == at(9, day: 8))
    #expect(window?.end == at(13, day: 8))
}

@Test func aMorningOffOnASaturdayIsTheSecondHalfOfTheSaturday() {
    // Anchored to the end of the day that is actually scheduled, not to clock-off. Tied
    // to clock-off it would run four to six on a Saturday nobody works in the afternoon.
    let window = withSaturdayMornings([key(8): .unpaidMorning])
        .workingWindow(on: at(10, day: 8), calendar: cal())
    #expect(window?.start == at(11, day: 8))
    #expect(window?.end == at(13, day: 8))
}

@Test func anAfternoonOffOnASaturdayIsTheFirstHalfOfTheSaturday() {
    let window = withSaturdayMornings([key(8): .unpaidAfternoon])
        .workingWindow(on: at(10, day: 8), calendar: cal())
    #expect(window?.start == at(9, day: 8))
    #expect(window?.end == at(11, day: 8))
}

// MARK: - The counts under the grid

@Test func aHalfDayOffCountsAsHalfADayOff() {
    let config = split([key(7): .unpaidLeave, key(12): .unpaidAfternoon])
    #expect(config.monthTotals(for: at(10), calendar: cal()).daysOffCount == 1.5)
    #expect(config.daysOffInMonth(of: at(10), calendar: cal()) == 1.5)
    #expect(earnings(config, at(10)).daysOffThisMonth == 1.5)
}

@Test func aHalfDayOffIsStillCountedAsAWorkday() {
    // Paid leave leaves the workday count and unpaid leave does not; a half day of unpaid
    // leave is unpaid leave.
    let totals = split([key(7): .unpaidMorning]).monthTotals(for: at(10), calendar: cal())
    #expect(totals.workdayCount == 21)
}

@Test func theGridAgreesWithTheSweepAboutHalfDays() {
    let config = split([key(7): .unpaidLeave, key(12): .unpaidMorning])
    let overview = config.monthOverview(for: at(10), now: at(10), calendar: cal())
    let totals = config.monthTotals(for: at(10), calendar: cal())
    #expect(overview.daysOffCount == totals.daysOffCount)
    #expect(overview.workdayCount == totals.workdayCount)
    #expect(overview.days.first { $0.key == key(12) }?.isHalfDayLeave == true)
    #expect(overview.days.first { $0.key == key(7) }?.isHalfDayLeave == false)
}

// MARK: - The click

@Test func aClickFromEitherHalfReturnsTheDayToWork() {
    // The halves are chosen from the menu, not the cycle, so a click on one has to go
    // somewhere obvious — and "back to a workday" is where a click on unpaid leave goes.
    #expect(DayOverride.next(after: .unpaidMorning) == nil)
    #expect(DayOverride.next(after: .unpaidAfternoon) == nil)
}

@Test func theClickCycleItselfIsUnchanged() {
    #expect(DayOverride.next(after: nil) == .paidLeave)
    #expect(DayOverride.next(after: .paidLeave) == .unpaidLeave)
    #expect(DayOverride.next(after: .unpaidLeave) == nil)
}
