import Foundation
import Testing
@testable import SalaryDomain

private func gregorian(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

private func noon(_ year: Int, _ month: Int, _ day: Int, zone: String) -> Date {
    var parts = DateComponents()
    parts.year = year; parts.month = month; parts.day = day; parts.hour = 12
    return gregorian(zone).date(from: parts)!
}

// MARK: - resolved() must never leave the day

@Test(arguments: [
    // Zone,                 date,          a wall-clock time swallowed by that day's DST gap
    ("America/Nuuk", 2026, 3, 28, 23, 30),        // 23:00 → 24:00, the gap ends the day
    ("Antarctica/Troll", 2026, 3, 29, 1, 30),     // two-hour gap, 01:00 → 03:00
    ("Australia/Lord_Howe", 2026, 10, 4, 2, 15),  // half-hour gap, 02:00 → 02:30
])
func resolvedStaysOnTheRequestedDayThroughDaylightSavingGaps(
    zone: String, year: Int, month: Int, day: Int, hour: Int, minute: Int
) {
    let calendar = gregorian(zone)
    let theDay = noon(year, month, day, zone: zone)
    let resolved = TimeOfDay(hour, minute).resolved(on: theDay, calendar: calendar)

    #expect(calendar.isDate(resolved, inSameDayAs: theDay))
}

@Test func aShiftInsideADaylightSavingGapKeepsStartBeforeEnd() {
    // Before the fix this produced start > end, so `guard cursor > start` failed all day
    // and a real five-hour shift paid exactly nothing — while the panel claimed the user
    // was still 21 hours away from clocking on.
    let zone = "Antarctica/Troll"
    let calendar = gregorian(zone)
    let theDay = noon(2026, 3, 29, zone: zone)

    let config = SalaryConfig(
        monthlySalary: 10_000,
        workStart: TimeOfDay(1, 0),
        workEnd: TimeOfDay(6, 0),
        lunchEnabled: false,
        workdays: [1, 2, 3, 4, 5, 6, 7]
    )
    let start = config.workStart.resolved(on: theDay, calendar: calendar)
    let end = config.workEnd.resolved(on: theDay, calendar: calendar)
    #expect(start < end)

    var parts = calendar.dateComponents([.year, .month, .day], from: theDay)
    parts.hour = 4
    let midShift = calendar.date(from: parts)!
    let result = EarningsCalculator.earnings(config: config, at: midShift, calendar: calendar)

    #expect(result.todayEarned > 0)
    if case .beforeWork = result.status {
        Issue.record("mid-shift should not report .beforeWork, got \(result.status)")
    }
}

@Test func aCountdownNeverExceedsTheLengthOfTheShift() {
    // The Nuuk symptom: a "24h 0m until clock-off" countdown during a 90-minute shift.
    let zone = "America/Nuuk"
    let calendar = gregorian(zone)
    let theDay = noon(2026, 3, 28, zone: zone)

    let config = SalaryConfig(
        monthlySalary: 10_000,
        workStart: TimeOfDay(22, 0),
        workEnd: TimeOfDay(23, 30),
        lunchEnabled: false,
        workdays: [1, 2, 3, 4, 5, 6, 7]
    )
    var parts = calendar.dateComponents([.year, .month, .day], from: theDay)
    parts.hour = 22; parts.minute = 30
    let duringShift = calendar.date(from: parts)!

    let result = EarningsCalculator.earnings(config: config, at: duringShift, calendar: calendar)
    if case .working(let endsIn) = result.status {
        #expect(endsIn <= config.dailyPaidSeconds)
    }
    // Whatever the status, the countdown may never claim a whole day.
    switch result.status {
    case .working(let t), .beforeWork(let t), .lunch(let t):
        #expect(t < 86_400)
    default:
        break
    }
}

@Test(arguments: [
    // The three zones an exhaustive sweep of every IANA zone across 2026 caught
    // resolving non-monotonically. Kept as a bounded regression test so the suite
    // stays fast: sweeping all zones takes ~30s, these take milliseconds.
    ("Antarctica/Troll", 2026, 3, 29),        // 01:00 → 03:00, a two-hour gap
    ("Australia/Lord_Howe", 2026, 10, 4),     // 02:00 → 02:30, a half-hour gap
    ("Pacific/Chatham", 2026, 9, 27),         // 02:45 → 03:45
    ("America/Nuuk", 2026, 3, 28),            // gap runs to the end of the day
    ("Africa/Cairo", 2026, 4, 24),            // gap starts at midnight
])
func resolvedIsMonotonicAcrossEveryMinuteOfATransitionDay(
    zone: String, year: Int, month: Int, day: Int
) {
    let calendar = gregorian(zone)
    let theDay = noon(year, month, day, zone: zone)
    var previous = Date.distantPast

    for minutes in 0..<(24 * 60) {
        let resolved = TimeOfDay(minutes / 60, minutes % 60).resolved(on: theDay, calendar: calendar)
        #expect(calendar.isDate(resolved, inSameDayAs: theDay),
                "\(zone) \(minutes / 60):\(minutes % 60) left the day → \(resolved)")
        #expect(resolved >= previous,
                "\(zone) \(minutes / 60):\(minutes % 60) went backwards → \(resolved) < \(previous)")
        previous = resolved
    }
}

@Test func ordinaryDaysStillResolveToTheExactWallClockTime() {
    let calendar = gregorian("Asia/Kuala_Lumpur")
    let theDay = noon(2026, 8, 5, zone: "Asia/Kuala_Lumpur")
    let resolved = TimeOfDay(9, 30).resolved(on: theDay, calendar: calendar)
    let parts = calendar.dateComponents([.hour, .minute], from: resolved)
    #expect(parts.hour == 9)
    #expect(parts.minute == 30)
}

// MARK: - The settings picker round trip

@Test(arguments: ["Africa/Monrovia", "Asia/Kuala_Lumpur", "America/New_York", "Asia/Kathmandu"])
func everyConfiguredTimeSurvivesTheSettingsPickerRoundTrip(zone: String) {
    // Africa/Monrovia ran UTC−00:44:30 until 1972. Anchoring the picker on the 1970
    // epoch there made `date(bySettingHour:)` return nil for 1416 of 1440 times a day,
    // so every non-round time in Settings silently displayed — and saved back — as 00:00.
    let calendar = gregorian(zone)
    let now = noon(2026, 8, 5, zone: zone)

    for hour in [0, 9, 12, 17, 23] {
        for minute in [0, 15, 30, 45, 59] {
            let original = TimeOfDay(hour, minute)
            let picker = original.asPickerDate(calendar: calendar, now: now)
            let roundTripped = TimeOfDay(from: picker, calendar: calendar)
            #expect(roundTripped == original, "\(zone) \(hour):\(minute) → \(roundTripped)")
        }
    }
}
