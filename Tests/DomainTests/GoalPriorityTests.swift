import Foundation
import Testing
@testable import SalaryDomain

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 1st is a Saturday, the 3rd a Monday, the 8th and 9th a weekend.
/// $10,000 over 21 working days is $476.190476 a day.
private func at(_ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

private let config = SalaryConfig(monthlySalary: 10_000, timeZoneIdentifier: "Asia/Kuala_Lumpur")
private let dayPay = 10_000.0 / 21.0

private func goal(_ name: String, _ amount: Double, from day: Int, _ hour: Int = 9) -> SavingsGoal {
    SavingsGoal(name: name, amount: amount, startedAt: at(day, hour))
}

private func project(_ goals: [SavingsGoal], at now: Date) -> [GoalProjection] {
    GoalCalculator.projections(for: goals, config: config, now: now, calendar: cal())
}

private func describe(_ date: Date?) -> String {
    guard let date else { return "nil" }
    let parts = cal().dateComponents([.month, .day, .hour, .minute], from: date)
    return String(format: "%02d-%02d %02d:%02d",
                  parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
}

// MARK: - One ringgit cannot buy two things
//
// Every goal used to count all the money earned since it began, independently of the
// others. Two goals therefore claimed the same earnings twice: with $3,333 in hand, two
// $3,000 goals both read 100% and the app cheerfully said you could afford both.
//
// Goals are now funded in the order the user puts them in, and each one only sees what the
// ones above it did not take.

@Test func twoGoalsCannotBothSpendTheSameMoney() {
    // Mon 3rd to Tue 11th, clock-off: seven full working days, $3,333.33.
    let goals = [goal("Laptop", 3_000, from: 3), goal("Trip", 3_000, from: 3)]
    let earned = 7 * dayPay
    let shown = project(goals, at: at(11, 18))

    #expect(abs(shown[0].earned - 3_000) < 1e-6)
    #expect(abs(shown[1].earned - (earned - 3_000)) < 1e-6)
    #expect(abs(shown.reduce(0) { $0 + $1.earned } - earned) < 1e-6)
    #expect(shown[0].progress == 1)
    #expect(shown[1].progress < 0.2)
}

@Test func theOrderTheyAreListedInIsTheOrderTheyAreFundedIn() {
    let laptop = goal("Laptop", 3_000, from: 3)
    let trip = goal("Trip", 3_000, from: 3)
    let now = at(11, 18)

    let laptopFirst = project([laptop, trip], at: now)
    let tripFirst = project([trip, laptop], at: now)

    #expect(abs(laptopFirst[0].earned - 3_000) < 1e-6)   // laptop full
    #expect(abs(tripFirst[0].earned - 3_000) < 1e-6)     // trip full instead
    #expect(laptopFirst[1].earned < 400)
    #expect(tripFirst[1].earned < 400)
}

@Test func aLowerPriorityGoalWaitsForTheOnesAboveItBeforeItStarts() {
    // Two full days each, nothing earned yet: the first lands after two days, the second
    // after four — not after two as well, which is what the old independent model said.
    let goals = [goal("First", dayPay * 2, from: 3), goal("Second", dayPay * 2, from: 3)]
    let shown = project(goals, at: at(3, 9))

    #expect(describe(shown[0].readyAt) == "08-04 18:00")
    #expect(describe(shown[1].readyAt) == "08-06 18:00")
}

@Test func aGoalAddedTodayCannotTakeBackMoneyAlreadySpentOnAnOlderOne() {
    // The chronology test, and the one that stops "sort by priority, then divide" from
    // passing for an implementation. The new goal is put at the TOP of the list, but the
    // week before it existed was already earned into the old one and cannot be reclaimed.
    let old = goal("Old", 500, from: 3)
    let new = goal("New", 500, from: 10)
    let shown = project([new, old], at: at(10, 18))

    #expect(abs(shown[1].earned - 500) < 1e-6)          // the old one kept its week
    #expect(abs(shown[0].earned - dayPay) < 1e-6)       // the new one has today only
}

@Test func aGoalStartedTodayStillWaitsForTheUnfinishedOneAboveIt() {
    let unfinished = goal("Big", dayPay * 10, from: 3)
    let fresh = goal("Small", dayPay, from: 10)
    let shown = project([unfinished, fresh], at: at(10, 9))

    // Mon 3rd to Fri 7th is five working days, and Monday the 10th has not started at
    // 09:00. All five went into the big one; it needs five more, and only then does the
    // small one get its day.
    #expect(abs(shown[0].earned - 5 * dayPay) < 1e-6)
    #expect(shown[1].earned == 0)
    #expect(shown[1].readyAt! > shown[0].readyAt!)
}

@Test(arguments: [3, 5, 10, 11])
func whatEveryGoalClaimsTogetherNeverExceedsWhatWasEarned(day: Int) {
    // The invariant the whole change exists for.
    let goals = [
        goal("A", 400, from: 3),
        goal("B", 1_200, from: 4),
        goal("C", 250, from: 5, 14),
    ]
    let now = at(day, 18)
    let claimed = project(goals, at: now).reduce(0) { $0 + $1.earned }
    let earned = GoalCalculator.earned(for: goals[0], config: config, now: now, calendar: cal())

    #expect(claimed <= earned + 1e-6, "claimed \(claimed) of \(earned) on the \(day)th")
}

// MARK: - Nothing changes for the ordinary case

@Test func asingleGoalBehavesExactlyAsItAlwaysDid() {
    let only = goal("Only", 2_000, from: 3)
    let now = at(11, 18)

    let viaList = project([only], at: now)[0]
    let viaSingle = GoalCalculator.projection(for: only, config: config, now: now, calendar: cal())

    #expect(abs(viaList.earned - viaSingle.earned) < 1e-9)
    #expect(viaList.readyAt == viaSingle.readyAt)
    #expect(abs(viaList.workdays - viaSingle.workdays) < 1e-9)
}

@Test func thePriceInWorkIsTheGoalsOwnAndDoesNotDependOnItsPlaceInTheQueue() {
    // Waiting your turn does not make a thing cost more work. Only the date moves.
    let goals = [goal("First", 3_000, from: 3), goal("Second", 1_000, from: 3)]
    let shown = project(goals, at: at(11, 18))
    let alone = project([goal("Second", 1_000, from: 3)], at: at(11, 18))[0]

    #expect(abs(shown[1].workdays - alone.workdays) < 1e-9)
    #expect(abs(shown[1].workSeconds - alone.workSeconds) < 1e-6)
}

@Test func anUnfinishedGoalTakesNothingAndBlocksNobody() {
    // A half-typed goal — no name, no amount — must not sit in the queue swallowing money.
    let goals = [
        SavingsGoal(name: "", amount: 0, startedAt: at(3)),
        goal("Real", 1_000, from: 3),
    ]
    let shown = project(goals, at: at(11, 18))

    #expect(shown[0].earned == 0)
    #expect(shown[0].readyAt == nil)
    #expect(abs(shown[1].earned - 1_000) < 1e-6)
}

@Test func anEmptyListProjectsNothing() {
    #expect(project([], at: at(11, 18)).isEmpty)
}

@Test func aCheapGoalDoesNotJumpTheQueueJustForBeingCheap() {
    // Deliberately built so that "fund in list order" and "fund the cheapest first" give
    // different answers: without it, a sort by amount passes the whole suite, because
    // every other case here happens to use goals of equal size.
    let expensive = goal("Expensive", 3_000, from: 3)
    let cheap = goal("Cheap", 400, from: 3)
    let twoDays = 2 * dayPay      // Mon 3rd and Tue 4th

    let shown = project([expensive, cheap], at: at(4, 18))

    #expect(abs(shown[0].earned - twoDays) < 1e-6)
    #expect(shown[1].earned == 0)
    // And the other way round, so neither ordering is hard-coded.
    let flipped = project([cheap, expensive], at: at(4, 18))
    #expect(abs(flipped[0].earned - 400) < 1e-6)
    #expect(abs(flipped[1].earned - (twoDays - 400)) < 1e-6)
}
