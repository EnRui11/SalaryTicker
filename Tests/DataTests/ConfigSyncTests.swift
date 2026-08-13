import Foundation
import Testing
@testable import SalaryData
import SalaryDomain

// The watch cannot scan a QR code, so its settings arrive from the phone over
// WatchConnectivity. What travels is the same link the QR encodes — one wire format, one
// set of version and tolerance rules, and one place to get them wrong.

private func sample() -> SalaryConfig {
    var config = SalaryConfig(monthlySalary: 4_500)
    config.monthlyAllowance = 500
    config.currencySymbol = "RM"
    config.timeZoneIdentifier = "Asia/Kuala_Lumpur"
    config.dayOverrides = [DayKey(year: 2026, month: 8, day: 31): .paidLeave]
    config.goals = [SavingsGoal(name: "Trip", amount: 10_000)]
    return config
}

@Test func aConfigSurvivesTheTripToTheWatch() {
    // Whole-second start times, which is what the stored format holds, so the comparison
    // is about the transfer rather than about floating point.
    var original = sample()
    original.goals = [SavingsGoal(name: "Trip", amount: 10_000,
                                  startedAt: Date(timeIntervalSince1970: 1_786_000_000))]

    #expect(ConfigSync.config(from: ConfigSync.payload(for: original)) == original)
}

@Test func aGoalCreatedThisInstantStillSurvivesTheTrip() {
    // A Date holds seconds since 2001 and the wire format holds seconds since 1970, so
    // moving between them loses bits below the nanosecond. Start times are stored to the
    // second precisely so a configuration can be compared with itself after a round trip.
    var original = sample()
    original.goals = [SavingsGoal(name: "Now", amount: 500)]      // startedAt = Date()

    let once = ConfigSync.config(from: ConfigSync.payload(for: original))!
    let twice = ConfigSync.config(from: ConfigSync.payload(for: once))!

    #expect(once == twice, "the trip has to be a fixed point, or nothing can be compared")
    #expect(abs(once.goals[0].startedAt.timeIntervalSince(original.goals[0].startedAt)) <= 0.5)
}

@Test func thePayloadIsSmallEnoughForAnApplicationContext() {
    // updateApplicationContext caps out around 262 kilobytes. Nowhere near it, but the
    // whole point of sending a link rather than a dictionary of every field is that the
    // size is bounded and known.
    let payload = ConfigSync.payload(for: sample())
    let size = try! JSONSerialization.data(withJSONObject: payload).count
    #expect(size < 4_096, "\(size) bytes")
}

@Test func anEmptyOrForeignPayloadIsRefusedRatherThanPartlyApplied() {
    #expect(ConfigSync.config(from: [:]) == nil)
    #expect(ConfigSync.config(from: ["something": "else"]) == nil)
    #expect(ConfigSync.config(from: ["salaryticker.config.link": "not a url at all"]) == nil)
    #expect(ConfigSync.config(from: ["salaryticker.config.link": 42]) == nil)
}

@Test func aPayloadCarryingSomebodyElsesLinkIsRefused() {
    // The same guard the QR path has: a link that is not ours does not become settings.
    #expect(ConfigSync.config(from: ["salaryticker.config.link": "https://example.com/?v=1&d=abc"]) == nil)
}

@Test func theWatchAndTheQrCodeCarryTheSameThing() {
    // If these two ever diverge, one of the two ways of setting up a device starts
    // producing different numbers from the other.
    let config = sample()
    let overTheAir = ConfigSync.config(from: ConfigSync.payload(for: config))
    let scanned = ConfigTransfer.config(from: ConfigTransfer.url(for: config))
    #expect(overTheAir == scanned)
}
