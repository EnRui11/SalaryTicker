import Foundation
import Testing
import SalaryDomain
@testable import SalaryApplication

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 3rd is a Monday, the 8th and 9th a weekend.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

/// 09:00–18:00, unpaid noon hour, Mon–Fri.
private let config = SalaryConfig(monthlySalary: 10_000, timeZoneIdentifier: "Asia/Kuala_Lumpur")

private func build(from now: Date, span: TimeInterval = 3600) -> [ComplicationTimeline.Entry] {
    ComplicationTimeline.entries(config: config, from: now, covering: span, calendar: cal())
}

// A watch complication cannot tick. What it can do is be handed a list of entries and told
// when to show each one, with no code running in between — which is exactly what a
// calculator that is a pure function of (config, now) can produce.
//
// The whole design question is *when* to place entries. A fixed entry a minute is wrong in
// both directions: wasteful all evening, when the figure has not moved since clock-off, and
// it says nothing about the moment that matters, which is the second the next shift starts.

@Test func theNumberIsSteppedThroughTheWorkingHour() {
    let entries = build(from: at(3, 10))

    #expect(entries.count > 1)
    #expect(entries.first?.date == at(3, 10))
    // Each entry is worth more than the one before it: this is a ticker, after all.
    for (earlier, later) in zip(entries, entries.dropFirst()) {
        #expect(later.date > earlier.date)
        #expect(later.earnings.todayEarned > earlier.earnings.todayEarned)
    }
}

@Test func aFrozenEveningIsOneEntryAndAWakeUpCallForTheMorning() {
    // After clock-off the figure does not move again until tomorrow. Repeating it sixty
    // times would spend a whole hour of a budget the system measures in refreshes a day.
    let entries = build(from: at(3, 19), span: 3600)

    #expect(entries.count == 2)
    #expect(entries[0].date == at(3, 19))
    // The second is the next thing that actually changes: tomorrow's clock-in.
    #expect(entries[1].date == at(4, 9))
    #expect(entries[1].earnings.todayEarned == 0)
}

@Test func aWeekendPointsAtMondayRatherThanTomorrow() {
    let entries = build(from: at(8, 12))          // Saturday lunchtime

    #expect(entries.count == 2)
    #expect(entries[1].date == at(10, 9))         // Monday, clock-in
}

@Test func theMorningBeforeWorkWaitsForTheShiftRatherThanCountingUpToIt() {
    // Before clock-in the figure is zero and stays zero, so the only interesting instant is
    // the start of the shift.
    let entries = build(from: at(3, 7))

    #expect(entries.count == 2)
    #expect(entries[0].earnings.todayEarned == 0)
    #expect(entries[1].date == at(3, 9))
}

@Test func lunchIsSteppedThroughEvenThoughTheNumberHoldsStill() {
    // The figure does not move across an unpaid lunch, but the shift has not ended and the
    // next entry is minutes away, not tomorrow. Treating it like an evening would leave the
    // complication asleep through the afternoon.
    let entries = build(from: at(3, 12, 30), span: 3600)

    #expect(entries.count > 2)
    #expect(entries.last!.date <= at(3, 13, 30))
    // It resumes moving once the hour is over.
    #expect(entries.last!.earnings.todayEarned > entries.first!.earnings.todayEarned)
}

@Test func theListIsBoundedSoAnHourCannotBecomeThousandsOfEntries() {
    let entries = build(from: at(3, 10), span: 24 * 3600)
    #expect(entries.count <= ComplicationTimeline.maximumEntries)
}

@Test func aMisconfiguredScheduleStillProducesSomethingToShow() {
    // A complication that returns nothing is a blank face with no way back.
    var broken = config
    broken.monthlySalary = 0
    let entries = ComplicationTimeline.entries(
        config: broken, from: at(3, 10), covering: 3600, calendar: cal()
    )

    #expect(entries.count >= 1)
    #expect(entries[0].earnings.todayEarned == 0)
}

@Test func everyEntryAgreesWithTheCalculatorItWillBeCheckedAgainst() {
    // The complication and the app must not disagree about the same instant, or the wrist
    // and the phone will show different money.
    for entry in build(from: at(3, 10)) {
        let direct = EarningsCalculator.earnings(config: config, at: entry.date, calendar: cal())
        #expect(abs(entry.earnings.todayEarned - direct.todayEarned) < 1e-9)
    }
}
