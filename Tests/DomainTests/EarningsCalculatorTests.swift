import Foundation
import Testing
@testable import SalaryDomain

// MARK: - Fixtures

private func calendar(_ zone: String = "Asia/Kuala_Lumpur") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: zone)!
    return cal
}

/// 2026-08-05 is a Wednesday; 2026-08-08 a Saturday.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5, month: Int = 8, year: Int = 2026,
                zone: String = "Asia/Kuala_Lumpur") -> Date {
    var parts = DateComponents()
    parts.year = year; parts.month = month; parts.day = day
    parts.hour = hour; parts.minute = minute
    return calendar(zone).date(from: parts)!
}

/// 09:00–18:00 with an unpaid 12:00–13:00 lunch → 8 paid hours a day.
private let standard = SalaryConfig(monthlySalary: 10_000)

private func hours(_ n: Double) -> TimeInterval { n * 3600 }

// MARK: - Rate derivation

@Test func dailyRateIsDerivedFromTheScheduleAndTheMonthsRealWorkingDays() {
    let august = at(12, 0)                             // 2026-08, Mon–Fri → 21 working days
    let cal = calendar()
    #expect(standard.dailyPaidMinutes == 480)          // 9h span − 1h lunch
    #expect(standard.workdaysInMonth(of: august, calendar: cal) == 21)
    #expect(standard.dailyPay(at: august, calendar: cal) == 10_000.0 / 21.0)
    #expect(abs(standard.hourlyPay(at: august, calendar: cal)
                - standard.dailyPay(at: august, calendar: cal) / 8) < 1e-9)
    #expect(abs(standard.ratePerSecond(at: august, calendar: cal) * 28_800
                - standard.dailyPay(at: august, calendar: cal)) < 1e-9)
}

@Test func afullMonthOfWorkingDaysAddsUpToExactlyTheMonthlySalary() {
    let cal = calendar()
    for (month, day) in [(8, 5), (2, 10), (11, 3)] {
        let date = at(12, 0, day: day, month: month)
        let days = standard.workdaysInMonth(of: date, calendar: cal)
        #expect(abs(Double(days) * standard.dailyPay(at: date, calendar: cal) - 10_000) < 1e-9)
    }
}

@Test func theDivisorTracksTheWeekdaySelection() {
    let august = at(12, 0)
    let cal = calendar()

    var everyDay = standard
    everyDay.workdays = [1, 2, 3, 4, 5, 6, 7]
    #expect(everyDay.workdaysInMonth(of: august, calendar: cal) == 31)

    var mondaysOnly = standard
    mondaysOnly.workdays = [2]
    #expect(mondaysOnly.workdaysInMonth(of: august, calendar: cal) == 5)   // Aug 3/10/17/24/31
}

@Test func aMonthWithFewerWorkingDaysPaysMorePerDay() {
    let cal = calendar()
    let august = at(12, 0)                              // 21 working days
    let february = at(12, 0, day: 10, month: 2)         // 2026-02 starts on a Sunday → 20
    #expect(standard.workdaysInMonth(of: february, calendar: cal) == 20)
    #expect(standard.dailyPay(at: february, calendar: cal)
            > standard.dailyPay(at: august, calendar: cal))
}

@Test func lunchOutsideWorkingHoursDeductsNothing() {
    var config = standard
    config.lunchStart = TimeOfDay(20, 0)
    config.lunchEnd = TimeOfDay(21, 0)
    #expect(config.unpaidLunchMinutes == 0)
    #expect(config.dailyPaidMinutes == 540)            // full 9h is paid
}

@Test func lunchPartiallyOverlappingWorkingHoursDeductsOnlyTheOverlap() {
    var config = standard
    config.lunchStart = TimeOfDay(17, 30)
    config.lunchEnd = TimeOfDay(18, 30)                // only 30 min falls inside
    #expect(config.unpaidLunchMinutes == 30)
    #expect(config.dailyPaidMinutes == 510)
}

// MARK: - Timeline boundaries

@Test func earnsNothingBeforeTheWorkdayStarts() {
    let result = EarningsCalculator.earnings(config: standard, at: at(8, 30), calendar: calendar())
    #expect(result.todayEarned == 0)
    #expect(result.status == .beforeWork(startsIn: hours(0.5)))
}

@Test func earnsNothingJustAfterMidnight() {
    let result = EarningsCalculator.earnings(config: standard, at: at(0, 30), calendar: calendar())
    #expect(result.todayEarned == 0)
    #expect(result.elapsedPaidSeconds == 0)
}

@Test func accruesDuringTheMorning() {
    let result = EarningsCalculator.earnings(config: standard, at: at(10, 0), calendar: calendar())
    #expect(result.elapsedPaidSeconds == hours(1))
    #expect(abs(result.todayEarned - standard.ratePerSecond(at: at(10, 0), calendar: calendar()) * hours(1)) < 1e-9)
    #expect(result.status == .working(endsIn: hours(8)))
}

@Test func pausesOverLunch() {
    let result = EarningsCalculator.earnings(config: standard, at: at(12, 30), calendar: calendar())
    #expect(result.elapsedPaidSeconds == hours(3))     // 09:00–12:00 only
    #expect(result.status == .lunch(endsIn: hours(0.5)))
}

@Test func resumesAfterLunch() {
    let result = EarningsCalculator.earnings(config: standard, at: at(14, 0), calendar: calendar())
    #expect(result.elapsedPaidSeconds == hours(4))     // 3h morning + 1h afternoon
}

@Test func freezesAtAFullDayAfterClockingOff() {
    let evening = EarningsCalculator.earnings(config: standard, at: at(20, 0), calendar: calendar())
    let midnightish = EarningsCalculator.earnings(config: standard, at: at(23, 59), calendar: calendar())
    #expect(evening.elapsedPaidSeconds == hours(8))
    #expect(abs(evening.todayEarned - standard.dailyPay(at: at(20, 0), calendar: calendar())) < 1e-9)
    #expect(evening.todayEarned == midnightish.todayEarned)   // stops growing
    #expect(evening.status == .afterWork)
    #expect(evening.progress == 1)
}

@Test func earnsNothingOnANonWorkday() {
    let saturday = EarningsCalculator.earnings(config: standard, at: at(14, 0, day: 8), calendar: calendar())
    #expect(saturday.todayEarned == 0)
    #expect(saturday.status == .dayOff)
}

// MARK: - Sleep / relaunch behaviour

@Test func theResultDependsOnlyOnTheClock() {
    // Sleeping for three hours must land on the same value as never having slept:
    // nothing is accumulated between ticks, so there is nothing to drift.
    let before = EarningsCalculator.earnings(config: standard, at: at(10, 0), calendar: calendar())
    let afterWaking = EarningsCalculator.earnings(config: standard, at: at(14, 0), calendar: calendar())
    #expect(afterWaking.elapsedPaidSeconds - before.elapsedPaidSeconds == hours(3))  // lunch excluded
}

@Test func daylightSavingSpringForwardKeepsWallClockHours() {
    // 2026-03-08 in New York loses the 02:00 hour. A 09:00 start must still mean
    // 09:00 on the wall clock, not "nine hours after midnight".
    let zone = "America/New_York"
    var config = standard
    config.workdays.insert(1)          // the transition always lands on a Sunday
    let result = EarningsCalculator.earnings(
        config: config,
        at: at(14, 0, day: 8, month: 3, zone: zone),
        calendar: calendar(zone)
    )
    #expect(result.elapsedPaidSeconds == hours(4))     // 09:00–12:00 + 13:00–14:00
}

@Test func daylightSavingFallBackNeverPaysMoreThanAFullDay() {
    // 2026-11-01 in New York is a 25-hour day: the 01:00 hour runs twice. A shift
    // configured 00:00–06:00 therefore spans seven real hours of six nominal ones.
    // Without the upper clamp the app would quietly overpay by a sixth.
    let zone = "America/New_York"
    let config = SalaryConfig(
        monthlySalary: 10_000,
        workStart: TimeOfDay(0, 0),
        workEnd: TimeOfDay(6, 0),
        lunchEnabled: false,
        workdays: [1, 2, 3, 4, 5, 6, 7]
    )
    let result = EarningsCalculator.earnings(
        config: config,
        at: at(6, 0, day: 1, month: 11, zone: zone),
        calendar: calendar(zone)
    )
    let fallBackDay = at(6, 0, day: 1, month: 11, zone: zone)
    #expect(config.dailyPaidMinutes == 360)
    #expect(result.elapsedPaidSeconds == hours(6))
    #expect(result.todayEarned <= config.dailyPay(at: fallBackDay, calendar: calendar(zone)) + 1e-9)
    #expect(result.progress <= 1)
}

@Test func theSameInstantMeansDifferentThingsInDifferentTimeZones() {
    // Directly pins the wall-clock contract: "09:00" is 09:00 wherever the calendar
    // says the user is, so one instant must not produce one shared answer.
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = 5; parts.hour = 14; parts.minute = 0
    let instant = calendar().date(from: parts)!          // 14:00 in Kuala Lumpur

    let local = EarningsCalculator.earnings(config: standard, at: instant, calendar: calendar())
    let newYork = EarningsCalculator.earnings(
        config: standard, at: instant, calendar: calendar("America/New_York")
    )

    #expect(local.elapsedPaidSeconds == hours(4))        // 09:00–12:00 + 13:00–14:00
    #expect(local.status == .working(endsIn: hours(4)))
    #expect(newYork.elapsedPaidSeconds == 0)             // still 02:00 there
    #expect(newYork.status == .beforeWork(startsIn: hours(7)))
}

@Test(arguments: [
    ("Asia/Kuala_Lumpur", 8, 5),      // ordinary day
    ("America/New_York", 3, 8),       // spring forward
    ("America/New_York", 11, 1),      // fall back
])
func earningsAreBoundedAtEveryMinuteOfTheDay(zone: String, month: Int, day: Int) {
    var config = standard
    config.workdays = [1, 2, 3, 4, 5, 6, 7]
    let cal = calendar(zone)
    let midnight = cal.startOfDay(for: at(12, 0, day: day, month: month, zone: zone))

    for step in stride(from: 0, through: 26 * 60, by: 5) {
        let now = midnight.addingTimeInterval(TimeInterval(step * 60))
        let result = EarningsCalculator.earnings(config: config, at: now, calendar: cal)
        #expect(result.todayEarned >= 0)
        #expect(result.todayEarned <= config.dailyPay(at: now, calendar: cal) + 1e-9)
        #expect(result.progress >= 0 && result.progress <= 1)
        #expect(result.todayEarned.isFinite)
    }
}

// MARK: - Month to date

@Test func monthToDateIsFinishedDaysPlusTodaySoFar() {
    // 2026-08-05 is the third Mon–Fri day of August (3rd, 4th, then today).
    let cal = calendar()
    let now = at(14, 0)
    let result = EarningsCalculator.earnings(config: standard, at: now, calendar: cal)

    #expect(result.workdaysCompletedThisMonth == 2)
    #expect(result.workdaysThisMonth == 21)

    let expected = 2 * standard.dailyPay(at: now, calendar: cal) + result.todayEarned
    #expect(abs(result.monthEarned - expected) < 1e-9)
}

@Test func theFirstWorkingDayOfTheMonthHasNothingBankedYet() {
    // 2026-08-03 is the first Monday of August; nothing precedes it.
    let result = EarningsCalculator.earnings(config: standard, at: at(10, 0, day: 3), calendar: calendar())
    #expect(result.workdaysCompletedThisMonth == 0)
    #expect(result.monthEarned == result.todayEarned)
}

@Test func aFullyWorkedMonthTotalsTheMonthlySalary() {
    // Last day of August 2026 (a Monday), after clock-off: 20 finished days + a full today.
    let cal = calendar()
    let result = EarningsCalculator.earnings(config: standard, at: at(23, 0, day: 31), calendar: cal)
    #expect(result.workdaysCompletedThisMonth == 20)
    #expect(result.elapsedPaidSeconds == standard.dailyPaidSeconds)
    #expect(abs(result.monthEarned - standard.monthlySalary) < 1e-9)
}

@Test func aWeekendDoesNotAddToTheMonthTotal() {
    let cal = calendar()
    let friday = EarningsCalculator.earnings(config: standard, at: at(23, 0, day: 7), calendar: cal)
    let saturday = EarningsCalculator.earnings(config: standard, at: at(14, 0, day: 8), calendar: cal)
    #expect(saturday.todayEarned == 0)
    #expect(abs(saturday.monthEarned - friday.monthEarned) < 1e-9)
}

@Test func theMonthTotalNeverExceedsTheMonthlySalary() {
    let cal = calendar()
    for day in 1...31 {
        for hour in [0, 9, 13, 18, 23] {
            let result = EarningsCalculator.earnings(config: standard, at: at(hour, 0, day: day), calendar: cal)
            #expect(result.monthEarned >= 0)
            #expect(result.monthEarned <= standard.monthlySalary + 1e-9)
            #expect(result.monthEarned.isFinite)
        }
    }
}

// MARK: - Misconfiguration (no NaN may ever reach the menu bar)

@Test func zeroLengthDayIsReportedInsteadOfDividingByZero() {
    var config = standard
    config.workEnd = config.workStart
    let result = EarningsCalculator.earnings(config: config, at: at(14, 0), calendar: calendar())
    #expect(result.status == .misconfigured)
    #expect(result.todayEarned == 0)
    #expect(result.ratePerSecond.isFinite)
}

@Test(arguments: [
    SalaryConfig(monthlySalary: 0),
    SalaryConfig(monthlySalary: .infinity),   // "1e400" / "∞" typed into the salary field
    SalaryConfig(monthlySalary: .nan),
    SalaryConfig(workdays: []),
    SalaryConfig(workStart: TimeOfDay(18, 0), workEnd: TimeOfDay(9, 0)),   // overnight: unsupported
])
func invalidConfigurationsNeverProduceNaN(config: SalaryConfig) {
    let result = EarningsCalculator.earnings(config: config, at: at(14, 0), calendar: calendar())
    #expect(result.status == .misconfigured)
    #expect(result.todayEarned.isFinite)
    #expect(result.progress.isFinite)
}
