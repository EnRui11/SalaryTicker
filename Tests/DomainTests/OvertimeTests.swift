import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// 2026-08-05 is a Wednesday; 2026-08-08 a Saturday.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

/// 09:00–18:00, unpaid 12:00–13:00, overtime on at 1.5× for up to 4 hours.
private func overtimeConfig(multiplier: Double = 1.5, maxHours: Int = 4) -> SalaryConfig {
    SalaryConfig(
        monthlySalary: 10_000,
        overtimeEnabled: true,
        overtimeMultiplier: multiplier,
        overtimeMaxHours: maxHours
    )
}

private func hours(_ n: Double) -> TimeInterval { n * 3600 }

@Test func overtimeIsZeroBeforeClockOff() {
    let result = EarningsCalculator.earnings(config: overtimeConfig(), at: at(17, 0), calendar: cal())
    #expect(result.overtimeSeconds == 0)
    #expect(result.overtimeEarned == 0)
    #expect(result.status == .working(endsIn: hours(1)))
}

@Test func overtimeAccruesAfterClockOffAtTheMultiplier() {
    let config = overtimeConfig()
    let result = EarningsCalculator.earnings(config: config, at: at(20, 0), calendar: cal())

    #expect(result.overtimeSeconds == hours(2))
    #expect(result.status == .overtime(elapsed: hours(2)))

    let rate = config.ratePerSecond(at: at(20, 0), calendar: cal())
    #expect(abs(result.overtimeEarned - hours(2) * rate * 1.5) < 1e-9)
    // A full regular day plus the overtime slice.
    #expect(abs(result.todayEarned - (config.dailyPay(at: at(20, 0), calendar: cal()) + result.overtimeEarned)) < 1e-9)
}

@Test func overtimeStopsAtTheConfiguredCap() {
    let config = overtimeConfig(maxHours: 2)
    let atCap = EarningsCalculator.earnings(config: config, at: at(20, 0), calendar: cal())
    let wellPast = EarningsCalculator.earnings(config: config, at: at(23, 30), calendar: cal())

    #expect(atCap.overtimeSeconds == hours(2))
    #expect(wellPast.overtimeSeconds == hours(2))          // frozen, not still climbing
    #expect(wellPast.todayEarned == atCap.todayEarned)
}

@Test func overtimeNeverSpillsPastMidnight() {
    // The cap is generous enough to reach midnight; the day boundary must stop it anyway,
    // so tomorrow still starts from zero.
    let config = overtimeConfig(maxHours: 12)
    let result = EarningsCalculator.earnings(config: config, at: at(23, 59), calendar: cal())
    #expect(result.overtimeSeconds <= hours(6))            // 18:00 → 24:00 at most
}

@Test func overtimeIsOffOnANonWorkday() {
    let saturday = EarningsCalculator.earnings(config: overtimeConfig(), at: at(20, 0, day: 8), calendar: cal())
    #expect(saturday.overtimeSeconds == 0)
    #expect(saturday.todayEarned == 0)
    #expect(saturday.status == .dayOff)
}

@Test func disabledOvertimeStillFreezesAtClockOff() {
    var config = overtimeConfig()
    config.overtimeEnabled = false
    let result = EarningsCalculator.earnings(config: config, at: at(22, 0), calendar: cal())

    #expect(result.overtimeSeconds == 0)
    #expect(result.status == .afterWork)
    #expect(result.elapsedPaidSeconds == config.dailyPaidSeconds)
}

@Test(arguments: [-1.0, 0.0, Double.nan, Double.infinity])
func anAbsurdMultiplierCannotProduceNonsense(multiplier: Double) {
    let config = overtimeConfig(multiplier: multiplier)
    let result = EarningsCalculator.earnings(config: config, at: at(20, 0), calendar: cal())
    #expect(result.overtimeEarned.isFinite)
    #expect(result.overtimeEarned >= 0)
    #expect(result.todayEarned.isFinite)
}

@Test func aHugeMultiplierIsClamped() {
    let config = overtimeConfig(multiplier: 1_000)
    #expect(config.effectiveOvertimeMultiplier == 10)
}

@Test func overtimeDoesNotDisturbTheMonthlyTotalOfARegularMonth() {
    // Month-to-date is finished days at the regular rate plus today; overtime rides along
    // inside today only, so it can never rewrite history.
    let config = overtimeConfig()
    let result = EarningsCalculator.earnings(config: config, at: at(20, 0), calendar: cal())
    let expected = Double(result.workdaysCompletedThisMonth) * result.dailyPay + result.todayEarned
    #expect(abs(result.monthEarned - expected) < 1e-9)
}

// MARK: - The toggle fully gates the feature

@Test func overtimeIsOffOutOfTheBox() {
    #expect(SalaryConfig.default.overtimeEnabled == false)
    #expect(SalaryConfig.default.overtimeCapSeconds == 0)
}

@Test(arguments: [at(9, 30), at(12, 30), at(17, 59), at(18, 0), at(20, 0), at(23, 59)])
func aSwitchedOffToggleBehavesExactlyAsIfTheFeatureDidNotExist(now: Date) {
    // The multiplier and cap are deliberately set to values that would be very visible if
    // they leaked: without the gate this config would pay triple for eight extra hours.
    var loaded = SalaryConfig(monthlySalary: 10_000)
    loaded.overtimeEnabled = false
    loaded.overtimeMultiplier = 3
    loaded.overtimeMaxHours = 8

    let plain = SalaryConfig(monthlySalary: 10_000)

    let withSettings = EarningsCalculator.earnings(config: loaded, at: now, calendar: cal())
    let without = EarningsCalculator.earnings(config: plain, at: now, calendar: cal())

    #expect(withSettings == without)
    #expect(withSettings.overtimeSeconds == 0)
    #expect(withSettings.overtimeEarned == 0)
}

@Test func aSwitchedOffToggleNeverReportsTheOvertimeStatus() {
    var off = SalaryConfig(monthlySalary: 10_000)
    off.overtimeEnabled = false
    off.overtimeMultiplier = 3

    for hour in 0...23 {
        let status = EarningsCalculator.earnings(config: off, at: at(hour, 0), calendar: cal()).status
        if case .overtime = status {
            Issue.record("overtime status at \(hour):00 with the toggle off")
        }
    }
}

@Test func theCapAndMultiplierOnlyMatterOnceSwitchedOn() {
    var off = SalaryConfig(monthlySalary: 10_000)
    off.overtimeEnabled = false
    off.overtimeMaxHours = 12
    #expect(off.overtimeCapSeconds == 0)

    off.overtimeEnabled = true
    #expect(off.overtimeCapSeconds == hours(12))
}

// MARK: - When the number is actually moving

@Test func onlyTheEarningStatesCountAsAccruing() {
    // Drives how often the app wakes up: a frozen number does not deserve a redraw a
    // second, all evening and all weekend.
    #expect(WorkStatus.working(endsIn: 60).isAccruing)
    #expect(WorkStatus.lunch(endsIn: 60).isAccruing)
    #expect(WorkStatus.overtime(elapsed: 60).isAccruing)

    #expect(WorkStatus.dayOff.isAccruing == false)
    #expect(WorkStatus.beforeWork(startsIn: 60).isAccruing == false)
    #expect(WorkStatus.afterWork.isAccruing == false)
    #expect(WorkStatus.misconfigured.isAccruing == false)
}

@Test func aDayMarkedOffIsNotAccruing() {
    var off = SalaryConfig(monthlySalary: 10_000)
    off.dayOverrides = [DayKey(year: 2026, month: 8, day: 5): .paidLeave]
    let result = EarningsCalculator.earnings(config: off, at: at(14, 0), calendar: cal())
    #expect(result.status.isAccruing == false)
}

// MARK: - A multiplier that pays nothing is not overtime

@Test(arguments: [0.0, -2.0, Double.nan])
func overtimeThatCannotPayIsNotAnnouncedAsOvertime(multiplier: Double) {
    // `effectiveOvertimeMultiplier` already refuses to pay at these values, but the seconds
    // were counted anyway and handed to the status line — so the panel read "Overtime for
    // 1h 20m" beside a number that had not moved since clock-off.
    let config = overtimeConfig(multiplier: multiplier)
    let earnings = EarningsCalculator.earnings(config: config, at: at(19, 20), calendar: cal())

    #expect(earnings.overtimeEarned == 0)
    #expect(earnings.overtimeSeconds == 0)
    #expect(earnings.status == .afterWork)
}

@Test func aMultiplierOfOneStillCountsAsOvertime() {
    // The boundary in the other direction: working past clock-off for ordinary pay is
    // still overtime, and must keep saying so.
    let config = overtimeConfig(multiplier: 1.0)
    let earnings = EarningsCalculator.earnings(config: config, at: at(19, 20), calendar: cal())

    #expect(earnings.overtimeSeconds == hours(1) + 20 * 60)
    #expect(earnings.overtimeEarned > 0)
    #expect(earnings.status == .overtime(elapsed: hours(1) + 20 * 60))
}
