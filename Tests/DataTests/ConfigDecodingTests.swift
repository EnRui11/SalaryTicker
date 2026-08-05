import Foundation
import Testing
@testable import SalaryData
import SalaryDomain

/// A repository over a throwaway defaults suite, seeded with raw JSON if given.
private func repository(seededWith json: String? = nil, suite: String) -> UserDefaultsSettingsRepository {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    if let json {
        defaults.set(Data(json.utf8), forKey: "salaryConfig")
    }
    return UserDefaultsSettingsRepository(defaults: defaults)
}

@Test func aConfigSavedBeforeTheLanguageSettingExistedStillLoads() {
    // Verbatim shape of what an earlier build wrote, including the long-removed
    // workDaysPerMonth key. Losing this would silently reset a user's salary, hours and
    // currency back to factory defaults on upgrade.
    let saved = """
    {"lunchStart":{"minute":0,"hour":12},"workDaysPerMonth":21.75,"monthlySalary":5000,
     "lunchEnabled":true,"workStart":{"minute":0,"hour":8},"lunchEnd":{"minute":0,"hour":13},
     "workEnd":{"minute":0,"hour":17},"workdays":[4,6,2,3,5],"fractionDigits":4,
     "currencySymbol":"$"}
    """

    let config = repository(seededWith: saved, suite: "test.legacy").load()

    #expect(config.monthlySalary == 5000)
    #expect(config.workStart == TimeOfDay(8, 0))
    #expect(config.workEnd == TimeOfDay(17, 0))
    #expect(config.currencySymbol == "$")
    #expect(config.workdays == [2, 3, 4, 5, 6])
    #expect(config.fractionDigits == 4)
    #expect(config.language == .english)      // the new field falls back to the default
}

@Test func anEmptyObjectLoadsTheDefaults() {
    #expect(repository(seededWith: "{}", suite: "test.empty").load() == .default)
}

@Test func nothingStoredLoadsTheDefaults() {
    #expect(repository(suite: "test.missing").load() == .default)
}

@Test func corruptStoredDataFallsBackToDefaultsRatherThanFailing() {
    #expect(repository(seededWith: "not json at all", suite: "test.corrupt").load() == .default)
}

@Test func unknownKeysAreIgnoredRatherThanFatal() {
    let config = repository(
        seededWith: #"{"monthlySalary":8000,"somethingFromTheFuture":{"a":1}}"#,
        suite: "test.future"
    ).load()
    #expect(config.monthlySalary == 8000)
}

@Test func anUnrecognisedLanguageDegradesToTheDefault() {
    let config = repository(seededWith: #"{"language":"klingon"}"#, suite: "test.lang").load()
    #expect(config.language == .english)
}

@Test func everySettingSurvivesASaveAndLoadRoundTrip() {
    for language in AppLanguage.allCases {
        let store = repository(suite: "test.roundtrip.\(language.rawValue)")
        var original = SalaryConfig.default
        original.language = language
        original.monthlySalary = 7321.5
        original.workStart = TimeOfDay(7, 45)
        original.workEnd = TimeOfDay(16, 15)
        original.workdays = [1, 3, 5]
        original.currencySymbol = "RM"
        original.fractionDigits = 2

        store.save(original)
        #expect(store.load() == original)
    }
}

@Test func englishIsTheDefaultLanguage() {
    #expect(SalaryConfig.default.language == .english)
}

@Test func anUnencodableConfigLeavesTheStoredOneIntact() {
    // JSONEncoder throws on a non-finite Double; the save must not take the app down,
    // and the previously saved settings must survive.
    let store = repository(suite: "test.unencodable")
    var good = SalaryConfig.default
    good.monthlySalary = 4200
    store.save(good)

    var broken = good
    broken.monthlySalary = .infinity
    store.save(broken)

    #expect(store.load() == good)
}

@Test func leaveAndHalfDaysSurviveASaveAndLoadRoundTrip() {
    let store = repository(suite: "test.leave")
    var original = SalaryConfig.default
    original.workdays.insert(7)
    original.halfDays = [7]
    original.dayOverrides = [
        DayKey(year: 2026, month: 8, day: 3): .paidLeave,
        DayKey(year: 2026, month: 8, day: 17): .unpaidLeave,
    ]

    store.save(original)
    #expect(store.load() == original)
}

@Test func aStoredOverrideThatNoLongerParsesIsDroppedRatherThanFailingTheLoad() {
    // A malformed key, or an override kind from a newer build, must not cost the user
    // every other setting they have.
    let saved = """
    {"monthlySalary":7000,
     "dayOverrides":{"2026-08-03":"paidLeave","garbage":"paidLeave","2026-08-04":"sabbatical"}}
    """
    let config = repository(seededWith: saved, suite: "test.badoverride").load()

    #expect(config.monthlySalary == 7000)
    #expect(config.dayOverrides == [DayKey(year: 2026, month: 8, day: 3): .paidLeave])
}

@Test func aConfigFromBeforeLeaveExistedLoadsWithNone() {
    let saved = #"{"monthlySalary":5000,"workdays":[2,3,4,5,6],"currencySymbol":"$"}"#
    let config = repository(seededWith: saved, suite: "test.preleave").load()

    #expect(config.monthlySalary == 5000)
    #expect(config.currencySymbol == "$")
    #expect(config.dayOverrides.isEmpty)
    #expect(config.halfDays.isEmpty)
}

@Test func theProgressRingIsOnByDefaultAndSurvivesARoundTrip() {
    #expect(SalaryConfig.default.menuBarShowsProgressRing)

    let store = repository(suite: "test.ring")
    var original = SalaryConfig.default
    original.menuBarShowsProgressRing = false
    store.save(original)
    #expect(store.load().menuBarShowsProgressRing == false)
}

@Test func aConfigFromBeforeTheRingExistedGetsItOn() {
    let config = repository(seededWith: #"{"monthlySalary":5000}"#, suite: "test.prering").load()
    #expect(config.menuBarShowsProgressRing)
}

@Test func goalsSurviveASaveAndLoadRoundTrip() {
    let store = repository(suite: "test.goals")
    var original = SalaryConfig.default
    original.goals = [
        SavingsGoal(name: "AirPods", amount: 1_100, isPinned: true,
                    startedAt: Date(timeIntervalSince1970: 1_780_000_000)),
        SavingsGoal(name: "Trip", amount: 9_000, isPinned: false,
                    startedAt: Date(timeIntervalSince1970: 1_781_000_000)),
    ]

    store.save(original)
    #expect(store.load() == original)
}

@Test func aGoalWithAnUnreadableIdIsDroppedRatherThanFailingTheLoad() {
    let saved = """
    {"monthlySalary":6000,"goals":[
      {"id":"not-a-uuid","name":"Bad","amount":10,"isPinned":true,"startedAt":0},
      {"id":"7B7D3E2A-1111-4222-8333-444455556666","name":"Good","amount":20,"isPinned":true,"startedAt":0}
    ]}
    """
    let config = repository(seededWith: saved, suite: "test.badgoal").load()

    #expect(config.monthlySalary == 6000)
    #expect(config.goals.count == 1)
    #expect(config.goals.first?.name == "Good")
}

@Test func aConfigFromBeforeGoalsExistedLoadsWithNone() {
    let config = repository(seededWith: #"{"monthlySalary":5000}"#, suite: "test.pregoals").load()
    #expect(config.goals.isEmpty)
}
