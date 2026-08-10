import Foundation
import Testing
import SalaryDomain
import SalaryCore
@testable import SalaryPresentation

// The schedule these tests run against is the author's real one, so a number that shows up
// in an assertion is a number that shows up in the menu bar.
//
// August 2026: the 1st is a Saturday, so Mon–Fri gives 21 working days.
// $5,000 a month over 21 days is $238.0952 a day, over 8 paid hours is $0.00826720 a second.
private let salary = 5_000.0
private let augustWorkdays = 21.0
private let septemberWorkdays = 22.0
private let julyWorkdays = 23.0
private let paidSecondsPerDay = 28_800.0
private let augustDayPay = salary / augustWorkdays
private let augustRate = augustDayPay / paidSecondsPerDay

private func testCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return calendar
}

private func at(_ hour: Int, _ minute: Int = 0, day: Int, month: Int = 8) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = month; parts.day = day
    parts.hour = hour; parts.minute = minute
    return testCalendar().date(from: parts)!
}

/// 08:00–17:00 with an unpaid hour at noon, Mon–Fri, read in a fixed zone so the numbers
/// do not depend on where the test runs.
private func liveConfig(
    goals: [SavingsGoal] = [], launchAtLogin: Bool = false
) -> SalaryConfig {
    SalaryConfig(
        monthlySalary: salary,
        workStart: TimeOfDay(8, 0),
        workEnd: TimeOfDay(17, 0),
        lunchStart: TimeOfDay(12, 0),
        lunchEnd: TimeOfDay(13, 0),
        timeZoneIdentifier: "Asia/Kuala_Lumpur",
        goals: goals,
        launchAtLoginEnabled: launchAtLogin
    )
}

@MainActor
private struct Rig {
    let viewModel: TickerViewModel
    let clock: FakeClock
    let settings: InMemorySettings
    let loginItem: FakeLoginItem

    /// Moves the clock and ticks, exactly as the running app does — the point being that
    /// the instance is never rebuilt, so anything it cached has to survive the move.
    func tick(to instant: Date) {
        clock.advance(to: instant)
        viewModel.refresh()
    }
}

@MainActor
private func rig(config: SalaryConfig = liveConfig(), start: Date) -> Rig {
    let clock = FakeClock(start)
    let settings = InMemorySettings(config)
    let loginItem = FakeLoginItem()
    let container = AppContainer(
        settings: settings, loginItem: loginItem, calendar: testCalendar()
    )
    return Rig(
        viewModel: TickerViewModel(container: container, clock: clock),
        clock: clock,
        settings: settings,
        loginItem: loginItem
    )
}

// MARK: - Midnight
//
// The app is meant to run for weeks without a restart, so every cache in the view model is
// keyed on which day it is. Nothing else in the suite can reach that: the calculators take
// `now` as an argument and have no memory to go stale.

@Test @MainActor func theDayStartsOverWithoutTheAppBeingRestarted() {
    // Wednesday afternoon: seven paid hours in, one hour of it eaten by lunch.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    #expect(abs(rig.viewModel.earnings.todayEarned - 7 * 3_600 * augustRate) < 1e-6)

    // Thursday morning, same instance, ten minutes into the shift.
    rig.tick(to: at(8, 10, day: 6))
    #expect(abs(rig.viewModel.earnings.todayEarned - 600 * augustRate) < 1e-6)
}

@Test @MainActor func theMonthTotalKeepsYesterdayAfterMidnight() {
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    // Monday and Tuesday finished, plus seven hours of Wednesday.
    let wednesday = rig.viewModel.earnings.monthEarned
    #expect(abs(wednesday - (2 * augustDayPay + 7 * 3_600 * augustRate)) < 1e-6)

    rig.tick(to: at(8, 10, day: 6))
    // Wednesday has joined the finished days rather than vanishing with the date.
    #expect(abs(rig.viewModel.earnings.monthEarned - (3 * augustDayPay + 600 * augustRate)) < 1e-6)
    #expect(rig.viewModel.earnings.monthEarned > wednesday)
}

@Test @MainActor func theGridsTodayMarkerMovesWithTheDay() {
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    #expect(rig.viewModel.monthOverview.days.first { $0.isToday }?.day == 5)
    #expect(rig.viewModel.monthOverview.completedWorkdayCount == 2)

    rig.tick(to: at(8, 10, day: 6))
    #expect(rig.viewModel.monthOverview.days.first { $0.isToday }?.day == 6)
    #expect(rig.viewModel.monthOverview.completedWorkdayCount == 3)
}

@Test @MainActor func aGoalsProgressIsNotStuckOnYesterdaysFigure() {
    // The panel caches the expensive half of a projection — everything banked before today
    // — and patches only the running total on top. That cache is keyed on the day, so if
    // the key ever failed to move the goal would silently stop counting whole days.
    let goal = SavingsGoal(name: "Bike", amount: 2_000, startedAt: at(8, 0, day: 3))
    let rig = rig(config: liveConfig(goals: [goal]), start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    #expect(abs(rig.viewModel.pinnedGoals[0].projection.earned
        - (2 * augustDayPay + 7 * 3_600 * augustRate)) < 1e-6)

    rig.tick(to: at(8, 10, day: 6))
    let shown = rig.viewModel.pinnedGoals[0].projection.earned
    // What a projection computed from scratch would say, with no cache in the way.
    let truth = GoalCalculator.projection(
        for: goal, config: liveConfig(goals: [goal]), now: at(8, 10, day: 6), calendar: testCalendar()
    ).earned
    #expect(abs(shown - truth) < 1e-6)
    #expect(abs(shown - (3 * augustDayPay + 600 * augustRate)) < 1e-6)
}

@Test @MainActor func theDailyRateChangesWhenTheMonthRollsOver() {
    // The sharper version of the same risk: a month sweep cached across a month boundary
    // would keep paying August's rate in September. The two months genuinely differ —
    // 21 working days against 22 — so the same salary buys a different day.
    let rig = rig(start: at(16, 0, day: 31))
    rig.viewModel.refresh()
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / augustWorkdays) < 1e-6)

    rig.tick(to: at(9, 0, day: 1, month: 9))
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / septemberWorkdays) < 1e-6)
    #expect(rig.viewModel.earnings.dailyPay < salary / augustWorkdays)
    // A new month starts from nothing, whatever August ended on.
    #expect(abs(rig.viewModel.earnings.monthEarned - 3_600 * (salary / septemberWorkdays / paidSecondsPerDay)) < 1e-6)
}

// MARK: - Paging the grid
//
// None of this was ever exercised: every one of these is a click, and clicks are the part
// of the app no test could reach until the view model came out of the executable.

@Test @MainActor func pagingToAnotherMonthDoesNotDisturbTheTicker() {
    // The grid can be paged to plan leave months ahead. The number in the menu bar must
    // keep describing today regardless — it is the one thing on screen that is not a plan.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    let today = rig.viewModel.earnings

    rig.viewModel.stepMonth(by: -1)
    #expect(rig.viewModel.isShowingCurrentMonth == false)
    #expect(rig.viewModel.monthOverview.days.count == 31)          // July
    #expect(rig.viewModel.monthOverview.days.contains { $0.isToday } == false)
    // July has 23 working days, so its days are worth less than August's.
    #expect(abs(rig.viewModel.displayedHourlyPay - salary / julyWorkdays / 8) < 1e-6)
    #expect(rig.viewModel.earnings == today)

    rig.viewModel.showCurrentMonth()
    #expect(rig.viewModel.isShowingCurrentMonth)
    #expect(rig.viewModel.monthOverview.days.first { $0.isToday }?.day == 5)
    #expect(abs(rig.viewModel.displayedHourlyPay - salary / augustWorkdays / 8) < 1e-6)
}

@Test @MainActor func pagingIsClampedRatherThanUnbounded() {
    let rig = rig(start: at(16, 0, day: 5))
    for _ in 0..<40 { rig.viewModel.stepMonth(by: 1) }
    #expect(rig.viewModel.monthOffset == 24)
    for _ in 0..<80 { rig.viewModel.stepMonth(by: -1) }
    #expect(rig.viewModel.monthOffset == -24)
}

// MARK: - Marking days

@Test @MainActor func cyclingADayGoesWorkingThenPaidThenUnpaidThenBack() {
    let rig = rig(start: at(16, 0, day: 5))
    let friday = DayKey(year: 2026, month: 8, day: 7)

    rig.viewModel.cycleDayOverride(friday)
    #expect(rig.viewModel.config.dayOverrides[friday] == .paidLeave)
    rig.viewModel.cycleDayOverride(friday)
    #expect(rig.viewModel.config.dayOverrides[friday] == .unpaidLeave)
    rig.viewModel.cycleDayOverride(friday)
    #expect(rig.viewModel.config.dayOverrides[friday] == nil)

    // Every click was written through, not just the last one.
    #expect(rig.settings.saveCount == 3)
    #expect(rig.settings.stored.dayOverrides[friday] == nil)
}

@Test @MainActor func markingAPaidHolidayRaisesTheDailyRateImmediately() {
    // The rule the author chose: paid leave leaves the divisor, so the same salary spreads
    // over fewer working days and every remaining day is worth more.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / 21) < 1e-6)

    rig.viewModel.cycleDayOverride(DayKey(year: 2026, month: 8, day: 7))
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / 20) < 1e-6)
    #expect(rig.viewModel.monthOverview.daysOffCount == 1)

    // Unpaid leave stays in the divisor: that is what makes it cost a day's pay.
    rig.viewModel.cycleDayOverride(DayKey(year: 2026, month: 8, day: 7))
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / 21) < 1e-6)
}

@Test @MainActor func aDayCanBeMarkedInAMonthTheGridHasBeenPagedTo() {
    // Marking next month's leave is the main reason the arrows exist.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.stepMonth(by: 1)

    let september = DayKey(year: 2026, month: 9, day: 2)
    rig.viewModel.cycleDayOverride(september)

    #expect(rig.settings.stored.dayOverrides[september] == .paidLeave)
    #expect(rig.viewModel.monthOverview.days.first { $0.day == 2 }?.override == .paidLeave)
    // August is being paid today, and August did not change.
    #expect(abs(rig.viewModel.earnings.dailyPay - salary / augustWorkdays) < 1e-6)
}

// MARK: - Goals, from the click that creates one

@Test @MainActor func aGoalAddedThisAfternoonDoesNotClaimThisMorningsWork() {
    // `addGoal` stamps the goal with the current instant. If it ever took the start of the
    // day instead, a goal added after lunch would arrive already part paid for.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.addGoal()
    rig.viewModel.config.goals[0].name = "Bike"
    rig.viewModel.config.goals[0].amount = 500
    rig.viewModel.configChanged()

    #expect(rig.viewModel.pinnedGoals.count == 1)
    #expect(rig.viewModel.pinnedGoals[0].projection.earned == 0)

    // Half an hour of work later, it has half an hour of work in it.
    rig.tick(to: at(16, 30, day: 5))
    #expect(abs(rig.viewModel.pinnedGoals[0].projection.earned - 1_800 * augustRate) < 1e-6)

    let id = rig.viewModel.config.goals[0].id
    rig.viewModel.removeGoal(id)
    #expect(rig.viewModel.pinnedGoals.isEmpty)
    #expect(rig.settings.stored.goals.isEmpty)
}

@Test @MainActor func anUnfinishedGoalIsNotShownInThePanel() {
    // `addGoal` deliberately creates an empty one for the user to fill in; until it has a
    // name and an amount there is nothing to say about it.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.addGoal()
    #expect(rig.viewModel.config.goals.count == 1)
    #expect(rig.viewModel.pinnedGoals.isEmpty)
}

// MARK: - Launch at login

@Test @MainActor func theStoredIntentIsWhatGetsRegisteredAtStartup() {
    let rig = rig(config: liveConfig(launchAtLogin: true), start: at(16, 0, day: 5))
    #expect(rig.loginItem.registerCount == 1)
    #expect(rig.viewModel.isLaunchAtLoginSupported)
}

@Test @MainActor func startingUpNeverRemovesAnEntryTheSystemMadeItself() {
    // macOS lists menu bar apps in Background Task Management merely for having run, and
    // reports that as enabled. "Never asked for auto-start" is not "take my entry away".
    let clock = FakeClock(at(16, 0, day: 5))
    let loginItem = FakeLoginItem(state: .enabled)
    let container = AppContainer(
        settings: InMemorySettings(liveConfig(launchAtLogin: false)),
        loginItem: loginItem,
        calendar: testCalendar()
    )
    _ = TickerViewModel(container: container, clock: clock)

    #expect(loginItem.unregisterCount == 0)
    #expect(loginItem.registerCount == 0)
    #expect(loginItem.state == .enabled)
}

// MARK: - The cheap path Settings uses must give the same answer as the expensive one

@Test @MainActor func theSettingsProjectionMatchesAFullComputation() {
    // Settings redraws once a second while it is open, and an uncached projection for an
    // old goal costs tens of milliseconds per goal. Serving it from the day-keyed cache is
    // only safe if the two paths cannot disagree.
    let goals = [
        SavingsGoal(name: "Pinned", amount: 3_000, isPinned: true, startedAt: at(9, 0, day: 3)),
        SavingsGoal(name: "Unpinned", amount: 800, isPinned: false, startedAt: at(15, 0, day: 4)),
        SavingsGoal(name: "New today", amount: 400, isPinned: true, startedAt: at(9, 30, day: 5)),
    ]
    let rig = rig(config: liveConfig(goals: goals), start: at(16, 0, day: 5))
    rig.viewModel.refresh()

    for goal in goals {
        let shown = rig.viewModel.projection(for: goal)
        let truth = GoalCalculator.projection(
            for: goal, config: liveConfig(goals: goals), now: at(16, 0, day: 5), calendar: testCalendar()
        )
        #expect(abs(shown.earned - truth.earned) < 1e-9, "\(goal.name)")
        #expect(abs(shown.workdays - truth.workdays) < 1e-9, "\(goal.name)")
        #expect(shown.readyAt == truth.readyAt, "\(goal.name)")
    }
}

@Test @MainActor func anUnpinnedGoalIsProjectedButNotShownInThePanel() {
    let goals = [SavingsGoal(name: "Someday", amount: 900, isPinned: false, startedAt: at(9, 0, day: 3))]
    let rig = rig(config: liveConfig(goals: goals), start: at(16, 0, day: 5))
    rig.viewModel.refresh()

    #expect(rig.viewModel.pinnedGoals.isEmpty)
    #expect(rig.viewModel.projection(for: goals[0]).readyAt != nil)
}

// MARK: - Hiding the amount

@Test @MainActor func hidingTheAmountFromThePanelSticksAndIsSaved() {
    // A click in the panel, which is the whole point: the moment you need this is not a
    // moment to go looking through a settings window.
    let rig = rig(start: at(16, 0, day: 5))
    #expect(rig.viewModel.config.menuBarHidesAmount == false)

    rig.viewModel.toggleMenuBarAmount()
    #expect(rig.viewModel.config.menuBarHidesAmount)
    #expect(rig.settings.stored.menuBarHidesAmount)

    rig.viewModel.toggleMenuBarAmount()
    #expect(rig.viewModel.config.menuBarHidesAmount == false)
    #expect(rig.settings.stored.menuBarHidesAmount == false)
    #expect(rig.settings.saveCount == 2)
}

@Test @MainActor func hidingTheAmountChangesNothingAboutWhatIsEarned() {
    // It is a display switch. If it ever touched the money the app would be lying twice.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.refresh()
    let before = rig.viewModel.earnings

    rig.viewModel.toggleMenuBarAmount()
    #expect(rig.viewModel.earnings.todayEarned == before.todayEarned)
    #expect(rig.viewModel.earnings.monthEarned == before.monthEarned)
}

@Test @MainActor func theHiddenStateSurvivesARelaunch() {
    // Quitting with the amount hidden and coming back to it on screen would defeat the
    // point of having hidden it.
    let rig = rig(start: at(16, 0, day: 5))
    rig.viewModel.toggleMenuBarAmount()

    let container = AppContainer(
        settings: rig.settings, loginItem: FakeLoginItem(), calendar: testCalendar()
    )
    let relaunched = TickerViewModel(container: container, clock: FakeClock(at(16, 0, day: 5)))
    #expect(relaunched.config.menuBarHidesAmount)
}
