import Foundation
import Testing
@testable import SalaryDomain

private let standard = SalaryConfig(monthlySalary: 10_000)

private func base(_ zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

/// 2026-08-05 14:00 in Kuala Lumpur, expressed as an absolute instant.
private let instant: Date = {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = 5; parts.hour = 14
    return base("Asia/Kuala_Lumpur").date(from: parts)!
}()

@Test func noTimeZoneChosenFollowsTheSystemClock() {
    let calendar = standard.calendar(basedOn: base("Asia/Kuala_Lumpur"))
    #expect(calendar.timeZone.identifier == "Asia/Kuala_Lumpur")
}

@Test func aChosenTimeZoneOverridesTheSystemClock() {
    var config = standard
    config.timeZoneIdentifier = "America/New_York"
    let calendar = config.calendar(basedOn: base("Asia/Kuala_Lumpur"))
    #expect(calendar.timeZone.identifier == "America/New_York")
}

@Test func anIdentifierTheSystemDoesNotKnowFallsBackToTheSystemClock() {
    // Falling back to UTC here would silently shift the whole working day.
    var config = standard
    config.timeZoneIdentifier = "Mars/Olympus_Mons"
    let calendar = config.calendar(basedOn: base("Asia/Kuala_Lumpur"))
    #expect(calendar.timeZone.identifier == "Asia/Kuala_Lumpur")
}

@Test func theSameInstantEarnsDifferentAmountsInDifferentChosenZones() {
    var local = standard                       // 14:00 in KL: 4 paid hours in
    local.timeZoneIdentifier = "Asia/Kuala_Lumpur"
    var newYork = standard                     // the same instant is 02:00 there
    newYork.timeZoneIdentifier = "America/New_York"

    let system = base("Asia/Kuala_Lumpur")
    let here = EarningsCalculator.earnings(config: local, at: instant, calendar: local.calendar(basedOn: system))
    let there = EarningsCalculator.earnings(config: newYork, at: instant, calendar: newYork.calendar(basedOn: system))

    #expect(here.elapsedPaidSeconds == 4 * 3600)
    #expect(there.elapsedPaidSeconds == 0)
    #expect(there.status == .beforeWork(startsIn: 7 * 3600))
}

@Test func everyKnownZoneProducesAFiniteResult() {
    // The picker offers every identifier the system knows, so every one of them has to
    // survive the whole calculation.
    let system = base("Asia/Kuala_Lumpur")
    for identifier in TimeZone.knownTimeZoneIdentifiers {
        var config = standard
        config.timeZoneIdentifier = identifier
        let result = EarningsCalculator.earnings(
            config: config, at: instant, calendar: config.calendar(basedOn: system)
        )
        #expect(result.todayEarned.isFinite, "\(identifier)")
        #expect(result.todayEarned >= 0, "\(identifier)")
        #expect(result.todayEarned <= config.dailyPay(at: instant, calendar: config.calendar(basedOn: system)) + 1e-9,
                "\(identifier)")
        #expect(result.progress >= 0 && result.progress <= 1, "\(identifier)")
    }
}
