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

@Test func aGoalWithAnUnreadableIdKeepsWhatTheUserTypedAndGetsANewIdentity() {
    // This used to drop the goal, on the grounds that losing one goal beat failing the
    // whole load. The decoder no longer fails that way, so the trade is gone: an id is
    // internal bookkeeping, while the name and the amount are the things the user chose.
    let saved = """
    {"monthlySalary":6000,"goals":[
      {"id":"not-a-uuid","name":"Bad","amount":10,"isPinned":true,"startedAt":0},
      {"id":"7B7D3E2A-1111-4222-8333-444455556666","name":"Good","amount":20,"isPinned":true,"startedAt":0}
    ]}
    """
    let config = repository(seededWith: saved, suite: "test.badgoal").load()

    #expect(config.monthlySalary == 6000)
    #expect(config.goals.count == 2)
    #expect(config.goals.map(\.name) == ["Bad", "Good"])
    #expect(config.goals[0].amount == 10)
    // The readable one keeps the identity it was saved with; only the broken one is new.
    #expect(config.goals[1].id == UUID(uuidString: "7B7D3E2A-1111-4222-8333-444455556666"))
    #expect(config.goals[0].id != config.goals[1].id)
}

@Test func aConfigFromBeforeGoalsExistedLoadsWithNone() {
    let config = repository(seededWith: #"{"monthlySalary":5000}"#, suite: "test.pregoals").load()
    #expect(config.goals.isEmpty)
}

// MARK: - A bad field must not take the whole configuration down with it
//
// The tolerant decoding above only forgives keys that are *absent*. Every one of these
// covers a key that is present with the wrong shape, which is what actually happens when a
// field changes between builds — and which used to throw, be swallowed by `load()`, and
// hand the user factory settings. The next save then wrote those defaults over the real
// config, so the loss was permanent.

@Test func oneUnreadableGoalCannotWipeTheWholeConfiguration() {
    // A goal written before `isPinned` existed. Everything else in the file is fine.
    let saved = """
    {"monthlySalary":5000,"currencySymbol":"RM","workdays":[2,3,4,5,6],
     "goals":[{"id":"A","name":"Bike","amount":2000,"startedAt":1785916285.0}]}
    """
    let config = repository(seededWith: saved, suite: "test.goalfield").load()

    #expect(config.monthlySalary == 5000)
    #expect(config.currencySymbol == "RM")
    #expect(config.goals.count == 1)
    #expect(config.goals.first?.name == "Bike")
    #expect(config.goals.first?.isPinned == true)   // the missing field takes the default
}

@Test func aFieldOfTheWrongTypeIsTreatedAsAbsentRatherThanFatal() {
    // fractionDigits is an Int; a Double there is exactly the kind of drift a hand-edit or
    // a changed field type produces.
    let saved = #"{"monthlySalary":7777,"currencySymbol":"RM","fractionDigits":2.5}"#
    let config = repository(seededWith: saved, suite: "test.wrongtype").load()

    #expect(config.monthlySalary == 7777)
    #expect(config.currencySymbol == "RM")
    #expect(config.fractionDigits == SalaryConfig.default.fractionDigits)
}

@Test func aGoalWrittenBeforeStartedAtExistedDoesNotClaimEveryYearSince1970() {
    // Defaulting the missing instant to the epoch would credit the goal with decades of
    // work. Starting the clock now under-claims instead, which is the safe direction.
    let saved = #"{"goals":[{"id":"A","name":"Bike","amount":2000,"isPinned":true}]}"#
    let config = repository(seededWith: saved, suite: "test.nostart").load()

    #expect(config.goals.count == 1)
    #expect(abs(config.goals.first?.startedAt.timeIntervalSinceNow ?? .infinity) < 5)
}

@Test func aGoalThatIsNotEvenAnObjectIsDroppedAndTheRestSurvive() {
    let saved = """
    {"monthlySalary":6000,
     "goals":[42,{"id":"B","name":"Kyoto","amount":9000,"isPinned":true,"startedAt":1785916285.0}]}
    """
    let config = repository(seededWith: saved, suite: "test.badelement").load()

    #expect(config.monthlySalary == 6000)
    #expect(config.goals.count == 1)
    #expect(config.goals.first?.name == "Kyoto")
}

@Test func aDayOverrideMapOfTheWrongShapeLosesOnlyTheOverrides() {
    let saved = #"{"monthlySalary":4321,"dayOverrides":{"2026-08-07":7}}"#
    let config = repository(seededWith: saved, suite: "test.badoverrides").load()

    #expect(config.monthlySalary == 4321)
    #expect(config.dayOverrides.isEmpty)
}

// MARK: - Allowance

@Test func aConfigSavedBeforeTheAllowanceExistedLoadsWithNone() {
    // The migration that matters most: everyone's stored config predates this field, and
    // reading it must leave every number exactly where it was.
    let saved = """
    {"monthlySalary":5000,"currencySymbol":"$","workStart":{"hour":8,"minute":0},
     "workEnd":{"hour":17,"minute":0},"workdays":[2,3,4,5,6]}
    """
    let config = repository(seededWith: saved, suite: "test.preallowance").load()

    #expect(config.monthlySalary == 5000)
    #expect(config.monthlyAllowance == 0)
    #expect(config.isValid)
}

@Test func theAllowanceSurvivesASaveAndLoadRoundTrip() {
    let store = repository(suite: "test.allowance")
    var original = SalaryConfig.default
    original.monthlySalary = 4_000
    original.monthlyAllowance = 1_000

    store.save(original)
    let loaded = store.load()
    #expect(loaded == original)
    #expect(loaded.monthlyAllowance == 1_000)
}
