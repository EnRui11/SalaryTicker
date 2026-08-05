import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 1st is a Saturday, the 5th a Wednesday, the 31st a Monday.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5, month: Int = 8) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = month; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

/// 09:00–18:00, unpaid 12:00–13:00, Mon–Fri. August 2026 has 21 workdays.
/// $10,000 a month → $476.19 a day → $59.52 an hour → $0.016534 a second.
private let standard = SalaryConfig(monthlySalary: 10_000)

/// Started today, so nothing has accrued towards it before this morning.
private func goal(_ amount: Double, _ name: String = "Thing", from start: Date? = nil) -> SavingsGoal {
    SavingsGoal(name: name, amount: amount, startedAt: start ?? at(0, 1))
}

private func project(
    _ amount: Double,
    at now: Date,
    config: SalaryConfig = standard,
    from start: Date? = nil
) -> GoalProjection {
    GoalCalculator.projection(
        for: goal(amount, from: start), config: config, now: now, calendar: cal()
    )
}

private func describe(_ date: Date?) -> String {
    guard let date else { return "nil" }
    let parts = cal().dateComponents([.month, .day, .hour, .minute], from: date)
    return String(format: "%02d-%02d %02d:%02d",
                  parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
}

// MARK: - The price in work

@Test func aGoalIsPricedInWorkingTime() {
    let dayPay = standard.dailyPay(at: at(10, 0), calendar: cal())
    let projection = project(dayPay, at: at(10, 0))

    #expect(abs(projection.workdays - 1) < 1e-9)
    #expect(abs(projection.workSeconds - standard.dailyPaidSeconds) < 1e-6)
}

@Test func halfADaysPayCostsHalfADay() {
    let dayPay = standard.dailyPay(at: at(10, 0), calendar: cal())
    #expect(abs(project(dayPay / 2, at: at(10, 0)).workdays - 0.5) < 1e-9)
}

@Test func thePriceInWorkDoesNotMoveWithTheClock() {
    // It is what the thing costs, not how far along you are.
    let morning = project(1_000, at: at(9, 30))
    let evening = project(1_000, at: at(17, 30))
    #expect(abs(morning.workSeconds - evening.workSeconds) < 1e-6)
}

// MARK: - The date it lands

@Test func somethingCheapArrivesLaterToday() {
    // One paid hour's worth, asked at 09:00 with nothing earned yet, lands at 10:00.
    let hourly = standard.hourlyPay(at: at(9, 0), calendar: cal())
    let projection = project(hourly, at: at(9, 0))
    #expect(describe(projection.readyAt) == "08-05 10:00")
    #expect(projection.earned == 0)
    #expect(projection.progress == 0)
}

@Test func theProjectionStepsOverLunchRatherThanThroughIt() {
    // Four paid hours from 09:00 is 14:00, not 13:00 — the unpaid hour does not count.
    let fourHours = standard.hourlyPay(at: at(9, 0), calendar: cal()) * 4
    #expect(describe(project(fourHours, at: at(9, 0)).readyAt) == "08-05 14:00")
}

@Test func aGoalBiggerThanTodayRollsIntoTheNextWorkingDay() {
    // Started at 17:00, so nothing counts yet. One paid hour is left today; the remaining
    // eight fill Thursday exactly.
    let nineHours = standard.hourlyPay(at: at(17, 0), calendar: cal()) * 9
    let projection = project(nineHours, at: at(17, 0), from: at(17, 0))
    #expect(describe(projection.readyAt) == "08-06 18:00")
}

@Test func theProjectionSkipsWeekends() {
    // Friday the 7th at 17:00, goal started this evening: one paid hour is left today, so
    // the second one is Monday morning.
    let twoHours = standard.hourlyPay(at: at(17, 0, day: 7), calendar: cal()) * 2
    let projection = project(twoHours, at: at(17, 0, day: 7), from: at(17, 0, day: 7))
    #expect(describe(projection.readyAt) == "08-10 10:00")
}

@Test func askingOutsideWorkingHoursStartsFromTheNextShift() {
    // 22:00 on Wednesday, started this evening: the first paid second available is 09:00
    // Thursday.
    let hourly = standard.hourlyPay(at: at(22, 0), calendar: cal())
    #expect(describe(project(hourly, at: at(22, 0), from: at(22, 0)).readyAt) == "08-06 10:00")
}

@Test func theDateHoldsStillAsTheDayGoesBy() {
    // The property that makes this worth showing at all: what you earn and what the clock
    // does advance together, so the promise stays put instead of running away from you.
    let amount = standard.dailyPay(at: at(10, 0), calendar: cal()) * 3

    let stamps = [at(9, 0), at(10, 0), at(11, 30), at(12, 30), at(14, 0), at(17, 0)]
        .map { project(amount, at: $0).readyAt }

    #expect(stamps.allSatisfy { $0 != nil })
    for stamp in stamps.dropFirst() {
        #expect(abs(stamp!.timeIntervalSince(stamps[0]!)) < 1)
    }
    // Three days of pay, started before work on Wednesday: Wednesday, Thursday, Friday.
    #expect(describe(stamps[0]) == "08-07 18:00")
}

@Test func aGoalWorthWholeDaysLandsOnTheLastOfThemRatherThanTheDayAfter() {
    // `amount / rate` leaves a sub-nanosecond crumb behind, and without a tolerance the
    // crumb pushes every round-numbered goal onto the next working day — across a weekend
    // that is a three-day error on the most ordinary case there is.
    let dayPay = standard.dailyPay(at: at(9, 0), calendar: cal())

    #expect(describe(project(dayPay, at: at(9, 0)).readyAt) == "08-05 18:00")
    #expect(describe(project(dayPay * 2, at: at(9, 0)).readyAt) == "08-06 18:00")
    #expect(describe(project(dayPay * 3, at: at(9, 0)).readyAt) == "08-07 18:00")
    // The fourth day is Monday: the weekend is exactly where this error used to hide.
    #expect(describe(project(dayPay * 4, at: at(9, 0)).readyAt) == "08-10 18:00")
}

@Test func progressTracksWhatHasBeenEarnedTowardsIt() {
    let dayPay = standard.dailyPay(at: at(10, 0), calendar: cal())
    // Two days' pay, half of which is one full day of work.
    let projection = project(dayPay * 2, at: at(18, 0))
    #expect(abs(projection.progress - 0.5) < 1e-9)
    #expect(abs(projection.earned - dayPay) < 1e-9)
}

@Test func aGoalAlreadyPaidForIsDoneRatherThanNegative() {
    let projection = project(1, at: at(18, 0))
    #expect(projection.progress == 1)
    #expect(projection.earned == 1)
    #expect(projection.readyAt != nil)
}

// MARK: - Degenerate input

@Test(arguments: [0.0, -5.0, Double.nan, Double.infinity])
func anImpossibleAmountIsReportedRatherThanGuessed(amount: Double) {
    let projection = project(amount, at: at(10, 0))
    #expect(projection.readyAt == nil)
    #expect(projection.workSeconds.isFinite)
    #expect(projection.workdays.isFinite)
}

@Test func aGoalNobodyCouldEverAffordDoesNotHangTheApp() {
    // Without a horizon the walk would never terminate. Five years of Mondays is the cap.
    let projection = project(1_000_000_000, at: at(10, 0))
    #expect(projection.readyAt == nil)
    #expect(projection.workSeconds > 0)
}

@Test func aMisconfiguredSalaryEarnsNothingAndProjectsNothing() {
    var broken = standard
    broken.monthlySalary = 0
    #expect(project(100, at: at(10, 0), config: broken).readyAt == nil)
}

@Test func aNamelessGoalIsNotValid() {
    #expect(SavingsGoal(name: "  ", amount: 100).isValid == false)
    #expect(SavingsGoal(name: "Laptop", amount: 0).isValid == false)
    #expect(SavingsGoal(name: "Laptop", amount: 100).isValid)
}

// MARK: - Interaction with the rest of the schedule

@Test func leavePushesTheDateOut() {
    // The one thing that does move the promise: changing the schedule under it.
    let twoDays = standard.dailyPay(at: at(9, 0), calendar: cal()) * 2

    var withLeave = standard
    withLeave.dayOverrides = [DayKey(year: 2026, month: 8, day: 6): .paidLeave]

    let plain = project(twoDays, at: at(9, 0))
    let delayed = project(twoDays, at: at(9, 0), config: withLeave)

    #expect(delayed.readyAt! > plain.readyAt!)
}

@Test func workingMoreDaysForTheSameSalaryMakesThingsCostMoreDays() {
    // A tempting thing to get backwards: adding Saturday shifts does not earn more, it
    // spreads the same monthly salary over more days. So each day buys less, and a fixed
    // price costs *more* working days than before.
    var withSaturday = standard
    withSaturday.workdays.insert(7)
    withSaturday.halfDays.insert(7)

    let price = 2_000.0
    let plain = project(price, at: at(9, 0, day: 7))
    let spread = project(price, at: at(9, 0, day: 7), config: withSaturday)

    #expect(spread.workdays > plain.workdays)
}

// MARK: - The cheap path must not drift from the expensive one

@Test func handingInAPrecomputedBankedFigureChangesNothing() {
    // The panel caches the expensive half and patches the running total on top. If the two
    // paths ever disagree the number on screen quietly stops matching the maths.
    var config = standard
    config.workdays.insert(7)
    config.halfDays.insert(7)
    config.dayOverrides = [DayKey(year: 2026, month: 8, day: 4): .paidLeave]

    let goals = [
        SavingsGoal(name: "New", amount: 500, startedAt: at(9, 30)),
        SavingsGoal(name: "A week old", amount: 3_000, startedAt: at(10, 0, day: 1)),
        SavingsGoal(name: "Started mid-afternoon", amount: 900, startedAt: at(15, 0, day: 3)),
    ]

    for goal in goals {
        for now in [at(9, 0), at(11, 30), at(12, 30), at(14, 0), at(18, 0), at(22, 0)] {
            let full = GoalCalculator.projection(for: goal, config: config, now: now, calendar: cal())
            let banked = GoalCalculator.earnedBeforeToday(
                for: goal, config: config, now: now, calendar: cal()
            )
            let cheap = GoalCalculator.projection(
                for: goal, config: config, now: now, earnedBeforeToday: banked, calendar: cal()
            )
            #expect(full == cheap, "\(goal.name) at \(describe(now))")
        }
    }
}

@Test func theTwoHalvesOfTheTotalAddUpToTheWhole() {
    let goal = SavingsGoal(name: "Split", amount: 5_000, startedAt: at(10, 0, day: 3))
    for now in [at(9, 0), at(14, 0), at(23, 0)] {
        let whole = GoalCalculator.earned(for: goal, config: standard, now: now, calendar: cal())
        let halves = GoalCalculator.earnedBeforeToday(for: goal, config: standard, now: now, calendar: cal())
            + GoalCalculator.earnedToday(for: goal, config: standard, now: now, calendar: cal())
        #expect(abs(whole - halves) < 1e-9)
    }
}
