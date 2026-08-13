import Foundation
import Testing
@testable import SalaryData
import SalaryDomain

// Getting the settings onto a phone is the thing standing between the port and being
// usable: iOS keeps its own defaults, so a fresh install starts on 10,000 a month and a
// nine-to-six day rather than on yours.
//
// The transfer is a URL. A QR code is only one way to deliver it — which matters, because
// a camera cannot be tested in a simulator and a URL can.

private func sample() -> SalaryConfig {
    var config = SalaryConfig(monthlySalary: 4_500)
    config.monthlyAllowance = 500
    config.workStart = TimeOfDay(8, 0)
    config.workEnd = TimeOfDay(17, 0)
    config.currencySymbol = "RM"
    config.language = .chinese
    config.timeZoneIdentifier = "Asia/Kuala_Lumpur"
    config.dayOverrides = [
        DayKey(year: 2026, month: 8, day: 31): .paidLeave,
        DayKey(year: 2026, month: 12, day: 25): .paidLeave,
    ]
    config.goals = [
        SavingsGoal(name: "Trip", amount: 10_000, startedAt: Date(timeIntervalSince1970: 1_780_000_000)),
        SavingsGoal(name: "Rope", amount: 800, isPinned: false,
                    startedAt: Date(timeIntervalSince1970: 1_781_000_000)),
    ]
    return config
}

@Test func aConfigSurvivesTheTripThroughAURL() {
    let original = sample()
    let url = ConfigTransfer.url(for: original)
    let restored = ConfigTransfer.config(from: url)

    #expect(restored == original)
}

@Test func theUrlIsSmallEnoughToPutInAQrCode() {
    // Byte mode at the lowest error correction tops out near 2,950 bytes. Staying well
    // under that keeps the code sparse enough to scan from a screen at arm's length.
    let url = ConfigTransfer.url(for: sample())
    #expect(url.absoluteString.count < 1_500, "\(url.absoluteString.count) characters")
}

@Test func aUrlMeantForSomethingElseIsRefused() {
    #expect(ConfigTransfer.config(from: URL(string: "https://example.com/config?v=1&d=abc")!) == nil)
    #expect(ConfigTransfer.config(from: URL(string: "salaryticker://something-else?v=1&d=abc")!) == nil)
}

@Test func rubbishIsRefusedRatherThanPartlyApplied() {
    // Half-importing a configuration would be worse than not importing one: the user would
    // be looking at a number built from a mixture of two machines.
    for bad in [
        "salaryticker://config",
        "salaryticker://config?v=1",
        "salaryticker://config?v=1&d=",
        "salaryticker://config?v=1&d=not-base64!!",
        "salaryticker://config?v=1&d=aGVsbG8=",          // valid base64, not a config
    ] {
        #expect(ConfigTransfer.config(from: URL(string: bad)!) == nil, "\(bad)")
    }
}

@Test func aPayloadFromALaterVersionIsRefusedRatherThanGuessedAt() {
    let url = ConfigTransfer.url(for: sample())
    let future = URL(string: url.absoluteString.replacingOccurrences(of: "v=1", with: "v=99"))!
    #expect(ConfigTransfer.config(from: future) == nil)
}

@Test func theEncodingSurvivesTheCharactersAUrlWouldOtherwiseEat() {
    // Base64 uses + and / and the payload travels in a query string, where both mean
    // something else. A currency symbol and a non-Latin name make the same point.
    var config = sample()
    config.currencySymbol = "€"
    config.goals = [SavingsGoal(name: "日本旅行 / 2027", amount: 12_000)]

    let restored = ConfigTransfer.config(from: ConfigTransfer.url(for: config))
    #expect(restored?.currencySymbol == "€")
    #expect(restored?.goals.first?.name == "日本旅行 / 2027")
}

@Test func anImportedConfigIsUsableRatherThanMerelyEqual() {
    // The point of the trip is that the phone then computes the same numbers as the Mac.
    let original = sample()
    let restored = ConfigTransfer.config(from: ConfigTransfer.url(for: original))!

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = 11; parts.hour = 12
    let noon = calendar.date(from: parts)!

    #expect(original.dailyPay(at: noon, calendar: calendar)
        == restored.dailyPay(at: noon, calendar: calendar))
    #expect(restored.isValid)
}

@Test func aPerfectlyGoodPayloadIsStillRefusedIfItArrivedAtTheWrongDoor() {
    // The earlier refusal test used rubbish payloads, so it passed whether or not the
    // scheme was ever checked — the decode failed either way. This one carries a payload
    // that would import cleanly, and must be turned away on the address alone.
    let valid = ConfigTransfer.url(for: sample()).absoluteString

    let wrongScheme = URL(string: valid.replacingOccurrences(of: "salaryticker://", with: "https://"))!
    let wrongHost = URL(string: valid.replacingOccurrences(of: "://config?", with: "://settings?"))!

    #expect(ConfigTransfer.config(from: wrongScheme) == nil)
    #expect(ConfigTransfer.config(from: wrongHost) == nil)
    // And the same payload at the right door still works, so the refusal is about the
    // address and nothing else.
    #expect(ConfigTransfer.config(from: URL(string: valid)!) != nil)
}

@Test func thePayloadUsesOnlyCharactersAQueryStringWillNotRewrite() {
    // Standard base64 spells things with + and /, and pads with =. Plenty of things that
    // carry a link — share sheets, web servers, some QR readers — read + in a query as a
    // space, and = comes back percent-escaped.
    //
    // One fixture cannot show this. Whether a payload happens to contain any of the three
    // depends on its exact length and bytes, and the first config tried here contained
    // none of them, so the test passed against standard base64 too. Walking the length
    // through every residue mod 3 guarantees the padding case at least.
    for extra in 0..<9 {
        var config = sample()
        config.goals = [SavingsGoal(name: String(repeating: "a", count: extra), amount: 1_234)]

        let url = ConfigTransfer.url(for: config)
        let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            .queryItems!.first { $0.name == "d" }!.value!

        #expect(payload.isEmpty == false)
        #expect(payload.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" },
                "name length \(extra) produced \(payload.suffix(6))")
        #expect(ConfigTransfer.config(from: url)?.goals.first?.amount == 1_234)
    }
}

@Test func theLinkIsDeflatedSoTheQrCodeStaysCoarseEnoughToScan() {
    // Every character is more modules in the same square. A realistic configuration is
    // about 900 bytes of JSON; left as-is the code is dense enough that scanning it from a
    // screen becomes a hunt for the right angle.
    let url = ConfigTransfer.url(for: sample())
    #expect(url.absoluteString.count < 800, "\(url.absoluteString.count) characters")
}

@Test func aLinkWrittenBeforeTheDeflationStillReads() {
    // Nothing has shipped uncompressed, but the diagnostic flag printed one, and a decoder
    // that only understands its own latest output is a decoder that breaks on upgrade.
    // One `sample()`, not two: it mints fresh goal ids on every call, so comparing against
    // a second one fails on identity alone and says nothing about the decoding.
    let original = sample()
    let json = try! JSONEncoder().encode(SalaryConfigDTO(original))
    let raw = json.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    let link = URL(string: "salaryticker://config?v=1&d=\(raw)")!

    #expect(ConfigTransfer.config(from: link) == original)
}
