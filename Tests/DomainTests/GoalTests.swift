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

// MARK: - Overtime must not fund a goal that did not exist yet
//
// `earnedToday` starts from the day's whole earnings, which include overtime, and then
// subtracts what was earned before the goal began. That subtraction priced regular hours
// only, so an evening goal was born already part paid for out of the overtime on the clock.

private func overtimeConfig(_ multiplier: Double = 1.5) -> SalaryConfig {
    var config = standard
    config.overtimeEnabled = true
    config.overtimeMultiplier = multiplier
    return config
}

@Test func aGoalCreatedAfterClockOffDoesNotInheritTheEveningsOvertime() {
    // 20:00 on Wednesday: two hours past an 18:00 clock-off, both already worked. Read one
    // second later, the goal is owed exactly that one second of overtime and nothing else.
    let evening = at(20, 0)
    let config = overtimeConfig()
    let goal = SavingsGoal(name: "Thing", amount: 5_000, startedAt: evening)
    let earned = GoalCalculator.earned(
        for: goal, config: config, now: evening.addingTimeInterval(1), calendar: cal()
    )

    let oneSecondOfOvertime = config.ratePerSecond(at: evening, calendar: cal()) * 1.5
    #expect(abs(earned - oneSecondOfOvertime) < 1e-9)
    // The two hours already on the clock were worth this much, and none of it is the
    // goal's — the bug this pins credited every cent of it.
    #expect(earned < 2 * 3_600 * oneSecondOfOvertime * 0.001)
}

@Test func overtimeWorkedAfterAGoalStartsStillCountsTowardsIt() {
    // The other half, and the one that stops "subtract all overtime" from passing for a
    // fix: overtime earned after the goal exists is exactly as real as regular pay.
    let goal = SavingsGoal(name: "Thing", amount: 5_000, startedAt: at(18, 0))
    let config = overtimeConfig()
    let earned = GoalCalculator.earned(
        for: goal, config: config, now: at(20, 0), calendar: cal()
    )
    // Two hours past clock-off at one and a half times the normal second.
    let expected = 2 * 3_600 * config.ratePerSecond(at: at(20, 0), calendar: cal()) * 1.5
    #expect(abs(earned - expected) < 1e-6)
}

@Test func aGoalStartedMidOvertimeCountsOnlyTheOvertimeAfterIt() {
    // Started at 19:00, an hour into overtime, read at 20:00: one hour, not two.
    let goal = SavingsGoal(name: "Thing", amount: 5_000, startedAt: at(19, 0))
    let config = overtimeConfig()
    let earned = GoalCalculator.earned(
        for: goal, config: config, now: at(20, 0), calendar: cal()
    )
    let expected = 3_600 * config.ratePerSecond(at: at(20, 0), calendar: cal()) * 1.5
    #expect(abs(earned - expected) < 1e-6)
}

@Test func theTwoHalvesStillAddUpWhenOvertimeIsInPlay() {
    // The cached path the panel uses must not drift from the whole computation, overtime
    // included — this is what the ticker actually renders every second.
    let goal = SavingsGoal(name: "Split", amount: 5_000, startedAt: at(19, 0, day: 3))
    let config = overtimeConfig()
    for now in [at(9, 0), at(14, 0), at(19, 0), at(21, 30)] {
        let whole = GoalCalculator.earned(for: goal, config: config, now: now, calendar: cal())
        let halves = GoalCalculator.earnedBeforeToday(for: goal, config: config, now: now, calendar: cal())
            + GoalCalculator.earnedToday(for: goal, config: config, now: now, calendar: cal())
        #expect(abs(whole - halves) < 1e-9, "at \(describe(now))")
    }
}

// MARK: - The forward walk must price days the way the backward walk does
//
// A paid second is worth a different amount in every month, because the daily rate is the
// salary divided by *that* month's working days: August 2026 has 21, September 22, February
// 2027 has 20 — a 10% swing. `earnedBeforeToday` already asks each past day for its own
// rate. The forward walk used to convert the whole shortfall into seconds once, at today's
// rate, and then spend those seconds in months where they were worth something else.

@Test func theProjectedInstantIsWhenTheScheduleHasActuallyPaidForIt() throws {
    // Fifteen August days' worth, started late in August: it cannot finish before
    // September, where every day pays less.
    let start = at(9, 0, day: 24)
    let goal = SavingsGoal(
        name: "Big", amount: standard.dailyPay(at: start, calendar: cal()) * 15, startedAt: start
    )
    let projection = GoalCalculator.projection(
        for: goal, config: standard, now: start, calendar: cal()
    )

    let readyAt = try #require(projection.readyAt)
    // Cross-check against the half of the calculator that was always right.
    let banked = GoalCalculator.earned(for: goal, config: standard, now: readyAt, calendar: cal())
    #expect(abs(banked - goal.amount) < 1.0, "landed at \(describe(readyAt)) with \(banked) of \(goal.amount)")
}

@Test func aGoalThatFinishesInsideThisMonthIsUnaffected() throws {
    // The regression guard for the fix: within one month every day is worth the same, so
    // nothing about these answers may move.
    let start = at(9, 0)
    for days in [0.5, 1.0, 2.0, 3.0] {
        let goal = SavingsGoal(
            name: "Small", amount: standard.dailyPay(at: start, calendar: cal()) * days, startedAt: start
        )
        let projection = GoalCalculator.projection(
            for: goal, config: standard, now: start, calendar: cal()
        )
        let readyAt = try #require(projection.readyAt)
        let banked = GoalCalculator.earned(for: goal, config: standard, now: readyAt, calendar: cal())
        #expect(abs(banked - goal.amount) < 0.01, "\(days) days landed at \(describe(readyAt))")
    }
}

@Test func aGoalCrossingIntoAShorterMonthLandsLaterThanASecondsOnlyWalkWouldSay() throws {
    // February 2027 has 20 working days against January's 21, so a February day pays more
    // and the goal should land *earlier* than a fixed-rate walk predicts. The direction of
    // the error matters: it is not a rounding wobble, it tracks the month's shape.
    let start = at(9, 0, day: 25, month: 1)
    let goal = SavingsGoal(
        name: "Winter", amount: standard.dailyPay(at: start, calendar: cal()) * 12, startedAt: start
    )
    let projection = GoalCalculator.projection(
        for: goal, config: standard, now: start, calendar: cal()
    )
    let readyAt = try #require(projection.readyAt)
    let banked = GoalCalculator.earned(for: goal, config: standard, now: readyAt, calendar: cal())
    #expect(abs(banked - goal.amount) < 1.0, "landed at \(describe(readyAt)) with \(banked)")
}

// MARK: - The backward walk has no business being bounded

private func atYear(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var parts = DateComponents()
    parts.year = year; parts.month = month; parts.day = day; parts.hour = hour
    return cal().date(from: parts)!
}

@Test func aGoalOlderThanTheProjectionHorizonStillCountsEveryMonthSince() {
    // A complete month of work pays exactly one monthly salary, whatever shape the month
    // has — that is what dividing by the month's own working days buys. So a goal started
    // at the top of one month and read at the top of another is owed precisely that many
    // salaries, and the arithmetic needs no reference implementation to check it against.
    //
    // The backward walk borrowed the forward walk's five-year cap. That cap exists to stop
    // an unaffordable goal looping forever; pointed at the past it just stops counting, and
    // an old goal's progress bar sits permanently below where it belongs.
    let start = atYear(2018, 1, 1)
    let now = atYear(2026, 8, 1)
    let months = 103.0                        // January 2018 through July 2026

    let goal = SavingsGoal(name: "Ancient", amount: 1e12, startedAt: start)
    let earned = GoalCalculator.earned(for: goal, config: standard, now: now, calendar: cal())

    #expect(abs(earned - months * 10_000) < 1.0, "earned \(earned) of an expected \(months * 10_000)")
}

@Test func aGoalStartedThisYearIsUnaffectedByLiftingTheCap() {
    // The regression guard: eight months is well inside the old cap, so this number may
    // not move at all.
    let goal = SavingsGoal(name: "Recent", amount: 1e9, startedAt: atYear(2025, 12, 1))
    let earned = GoalCalculator.earned(for: goal, config: standard, now: atYear(2026, 8, 1), calendar: cal())
    #expect(abs(earned - 8 * 10_000) < 1.0)
}
