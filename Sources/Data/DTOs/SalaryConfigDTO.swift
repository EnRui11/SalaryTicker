import Foundation
import SalaryDomain

/// The on-disk shape of `SalaryConfig`.
///
/// Separate from the domain value object so that a storage format change — a renamed key,
/// a dropped field — never forces a change to the type the calculator and UI speak.
struct SavingsGoalDTO: Codable, Equatable {
    var id: String
    var name: String
    var amount: Double
    var isPinned: Bool
    /// Seconds since the epoch, so the stored file stays readable and time-zone free.
    var startedAt: Double

    init(id: String, name: String, amount: Double, isPinned: Bool, startedAt: Double) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isPinned = isPinned
        self.startedAt = startedAt
    }

    /// As tolerant as the configuration around it, and for a sharper reason: a goal is
    /// nested inside that configuration, so a strict decoder here does not lose one goal —
    /// it throws out of the enclosing `init(from:)` and loses everything the user has.
    ///
    /// This has to live in the type body, not an extension: `Codable` is declared on the
    /// type, so the compiler synthesizes the strict witness at that point and an extension
    /// only adds an unused overload beside it.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.lenient(String.self, .id) ?? UUID().uuidString
        name = container.lenient(String.self, .name) ?? ""
        amount = container.lenient(Double.self, .amount) ?? 0
        isPinned = container.lenient(Bool.self, .isPinned) ?? true
        // A config written before this field existed cannot say when saving began. The
        // epoch would credit the goal with every year since 1970; starting the clock now
        // under-claims instead, which is the direction to be wrong in.
        startedAt = container.lenient(Double.self, .startedAt) ?? Date().timeIntervalSince1970
    }
}

struct SalaryConfigDTO: Codable, Equatable {
    struct TimeOfDayDTO: Codable, Equatable {
        var hour: Int
        var minute: Int
    }

    var monthlySalary: Double
    var workStart: TimeOfDayDTO
    var workEnd: TimeOfDayDTO
    var lunchEnabled: Bool
    var lunchStart: TimeOfDayDTO
    var lunchEnd: TimeOfDayDTO
    var workdays: Set<Int>
    var halfDays: Set<Int>
    var currencySymbol: String
    var fractionDigits: Int
    var language: String
    var timeZoneIdentifier: String?
    /// Day key → override, both as strings so the file stays readable and stable.
    var dayOverrides: [String: String]
    var goals: [SavingsGoalDTO]
    var menuBarShowsProgressRing: Bool
    var menuBarShowsCurrencySymbol: Bool
    var menuBarIconOnlyWhenIdle: Bool
    var overtimeEnabled: Bool
    var overtimeMultiplier: Double
    var overtimeMaxHours: Int
    var launchAtLoginEnabled: Bool

    /// Every key is optional on the way in, falling back to the default — and every key is
    /// read leniently, so a key that is present but the wrong shape is treated the same as
    /// one that is absent.
    ///
    /// Both halves matter, and the second half is the one that bites. Without the first,
    /// adding a field would make the synthesized decoder throw on every previously saved
    /// config. Without the second, so would changing a field's type, or one malformed goal
    /// in the list — and the failure is not a visible error but a silent reset to factory
    /// settings that the next save writes permanently over the user's own. Unknown keys
    /// left over from removed features (`workDaysPerMonth`) are ignored for the same reason.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SalaryConfigDTO(SalaryConfig.default)

        monthlySalary = container.lenient(Double.self, .monthlySalary) ?? fallback.monthlySalary
        workStart = container.lenient(TimeOfDayDTO.self, .workStart) ?? fallback.workStart
        workEnd = container.lenient(TimeOfDayDTO.self, .workEnd) ?? fallback.workEnd
        lunchEnabled = container.lenient(Bool.self, .lunchEnabled) ?? fallback.lunchEnabled
        lunchStart = container.lenient(TimeOfDayDTO.self, .lunchStart) ?? fallback.lunchStart
        lunchEnd = container.lenient(TimeOfDayDTO.self, .lunchEnd) ?? fallback.lunchEnd
        workdays = container.lenient(Set<Int>.self, .workdays) ?? fallback.workdays
        halfDays = container.lenient(Set<Int>.self, .halfDays) ?? fallback.halfDays
        currencySymbol = container.lenient(String.self, .currencySymbol) ?? fallback.currencySymbol
        fractionDigits = container.lenient(Int.self, .fractionDigits) ?? fallback.fractionDigits
        language = container.lenient(String.self, .language) ?? fallback.language
        timeZoneIdentifier = container.lenient(String.self, .timeZoneIdentifier)
        dayOverrides = container.lenient([String: String].self, .dayOverrides) ?? fallback.dayOverrides
        // Element by element: one goal the decoder cannot make sense of is dropped, and
        // every other goal — and the whole configuration around them — survives it.
        goals = (container.lenient([Lossy<SavingsGoalDTO>].self, .goals) ?? []).compactMap(\.value)
        menuBarShowsProgressRing = container.lenient(Bool.self, .menuBarShowsProgressRing)
            ?? fallback.menuBarShowsProgressRing
        menuBarShowsCurrencySymbol = container.lenient(Bool.self, .menuBarShowsCurrencySymbol)
            ?? fallback.menuBarShowsCurrencySymbol
        menuBarIconOnlyWhenIdle = container.lenient(Bool.self, .menuBarIconOnlyWhenIdle)
            ?? fallback.menuBarIconOnlyWhenIdle
        overtimeEnabled = container.lenient(Bool.self, .overtimeEnabled) ?? fallback.overtimeEnabled
        overtimeMultiplier = container.lenient(Double.self, .overtimeMultiplier)
            ?? fallback.overtimeMultiplier
        overtimeMaxHours = container.lenient(Int.self, .overtimeMaxHours) ?? fallback.overtimeMaxHours
        launchAtLoginEnabled = container.lenient(Bool.self, .launchAtLoginEnabled)
            ?? fallback.launchAtLoginEnabled
    }
}

// MARK: - Tolerant decoding

/// Decodes what it can and reports the rest as nil, so one unreadable element cannot fail
/// the array it sits in.
private struct Lossy<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: any Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    /// Absent, null, or present with the wrong type — all three read as "not there".
    ///
    /// `decodeIfPresent` forgives only the first two, which is the difference between an
    /// upgrade that keeps the user's settings and one that quietly discards them.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let value = try? decodeIfPresent(type, forKey: key) else { return nil }
        return value
    }
}
