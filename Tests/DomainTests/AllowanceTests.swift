import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 1st is a Saturday, the 31st a Monday, and Mon–Fri gives 21 working days.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

private func key(_ day: Int) -> DayKey { DayKey(year: 2026, month: 8, day: day) }

/// $4,000 basic plus a $1,000 allowance: the same $5,000 a month, split the way a payslip
/// splits it. 09:00–18:00, Mon–Fri.
private func split(_ overrides: [DayKey: DayOverride] = [:]) -> SalaryConfig {
    var config = SalaryConfig(monthlySalary: 4_000)
    config.monthlyAllowance = 1_000
    config.dayOverrides = overrides
    return config
}

/// Everything the month has paid once its last working day is over.
private func monthTotal(_ config: SalaryConfig) -> Double {
    EarningsCalculator.earnings(config: config, at: at(23, 0, day: 31), calendar: cal()).monthEarned
}

// MARK: - What unpaid leave is allowed to take
//
// The app used to know one number, so unpaid leave took a day of all of it. A payslip does
// not work that way: leave without pay comes off the basic, and the allowance is paid in
// full regardless. Taking a day off used to cost $238.10 of a $5,000 month when the real
// cost was $190.48 — the app over-charged by a quarter of a day, every day.

@Test func aFullMonthPaysTheBasicAndTheAllowanceAndNothingElse() {
    #expect(abs(monthTotal(split()) - 5_000) < 1e-6)
}

@Test func unpaidLeaveCostsADayOfBasicAndNoneOfTheAllowance() {
    let withLeave = monthTotal(split([key(7): .unpaidLeave]))

    // A day of basic is 4,000/21. A day of the whole 5,000 would be 238.10, and that is
    // what the single-number model charged.
    #expect(abs(withLeave - (5_000 - 4_000 / 21)) < 1e-6)
    #expect(abs((5_000 - withLeave) - 190.476190) < 1e-5)
}

@Test func theAllowanceArrivesInFullHoweverMuchUnpaidLeaveIsTaken() {
    // Three days off: the basic loses three days, the allowance loses nothing.
    let withLeave = monthTotal(split([key(7): .unpaidLeave, key(12): .unpaidLeave, key(13): .unpaidLeave]))
    #expect(abs(withLeave - (4_000 * 18 / 21 + 1_000)) < 1e-6)
}

@Test func paidLeaveStillLeavesBothDivisorsAndTheMonthStillTotals() {
    // The rule that was already there, now applied to both halves: a paid holiday does not
    // cost anything, it makes every remaining day worth more.
    let withHoliday = split([key(7): .paidLeave])
    #expect(abs(monthTotal(withHoliday) - 5_000) < 1e-6)

    // Twenty working days left carrying the whole month between them.
    #expect(abs(withHoliday.dailyPay(at: at(9, 0), calendar: cal()) - 5_000 / 20) < 1e-6)
}

@Test func theTickerIncludesTheAllowanceInWhatASecondIsWorth() {
    // The number in the menu bar is what you are earning, not what your basic is.
    let config = split()
    let dayPay = config.dailyPay(at: at(9, 0), calendar: cal())
    #expect(abs(dayPay - 5_000 / 21) < 1e-6)
    #expect(abs(config.ratePerSecond(at: at(9, 0), calendar: cal()) - dayPay / 28_800) < 1e-9)
}

@Test func unpaidLeaveRaisesTheAllowancePartOfEveryOtherDay() {
    // The allowance is a fixed monthly sum spread over the days that actually earn, so
    // taking a day off makes the remaining days carry a slightly larger share of it. The
    // basic behaves the other way round, which is the whole distinction.
    let plain = split()
    let withLeave = split([key(7): .unpaidLeave])

    let basicPerDay = 4_000 / 21.0
    #expect(abs(withLeave.dailyPay(at: at(9, 0), calendar: cal()) - (basicPerDay + 1_000 / 20.0)) < 1e-6)
    #expect(withLeave.dailyPay(at: at(9, 0), calendar: cal()) > plain.dailyPay(at: at(9, 0), calendar: cal()))
}

// MARK: - Degenerate and unchanged cases

@Test func anAllowanceOfZeroLeavesEveryExistingAnswerAlone() {
    // The regression guard for every user who has not set one: the arithmetic must be
    // bit-for-bit what it was before the field existed.
    let before = SalaryConfig(monthlySalary: 10_000)
    var after = before
    after.monthlyAllowance = 0

    for day in [5, 7, 31] {
        #expect(before.dailyPay(at: at(9, 0, day: day), calendar: cal())
            == after.dailyPay(at: at(9, 0, day: day), calendar: cal()))
    }
    #expect(abs(before.dailyPay(at: at(9, 0), calendar: cal()) - 10_000 / 21) < 1e-9)
}

@Test func aMonthEntirelyOnLeaveDividesByNothingRatherThanCrashing() {
    var everyDayOff: [DayKey: DayOverride] = [:]
    for day in 1...31 { everyDayOff[key(day)] = .unpaidLeave }
    let config = split(everyDayOff)

    #expect(config.dailyPay(at: at(9, 0), calendar: cal()).isFinite)
    #expect(monthTotal(config) == 0)
}

@Test(arguments: [-1.0, Double.nan, Double.infinity])
func anImpossibleAllowanceIsRefusedRatherThanTurningEverythingIntoNaN(amount: Double) {
    var config = SalaryConfig(monthlySalary: 5_000)
    config.monthlyAllowance = amount
    #expect(config.isValid == false)
}

@Test func anAllowanceWithNoBasicIsStillNotAValidSchedule() {
    // The salary field is the one that has to be there; an allowance on its own is a
    // half-filled form, not a job.
    var config = SalaryConfig(monthlySalary: 0)
    config.monthlyAllowance = 3_000
    #expect(config.isValid == false)
}
