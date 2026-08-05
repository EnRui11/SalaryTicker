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

    /// Every key is optional on the way in, falling back to the default.
    ///
    /// Without this, adding a single field would make the synthesized decoder throw on
    /// every previously saved config — and the app would silently greet the user with
    /// factory settings instead of their own. Unknown keys left over from removed
    /// features (`workDaysPerMonth`) are ignored for the same reason.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SalaryConfigDTO(SalaryConfig.default)

        monthlySalary = try container.decodeIfPresent(Double.self, forKey: .monthlySalary)
            ?? fallback.monthlySalary
        workStart = try container.decodeIfPresent(TimeOfDayDTO.self, forKey: .workStart)
            ?? fallback.workStart
        workEnd = try container.decodeIfPresent(TimeOfDayDTO.self, forKey: .workEnd)
            ?? fallback.workEnd
        lunchEnabled = try container.decodeIfPresent(Bool.self, forKey: .lunchEnabled)
            ?? fallback.lunchEnabled
        lunchStart = try container.decodeIfPresent(TimeOfDayDTO.self, forKey: .lunchStart)
            ?? fallback.lunchStart
        lunchEnd = try container.decodeIfPresent(TimeOfDayDTO.self, forKey: .lunchEnd)
            ?? fallback.lunchEnd
        workdays = try container.decodeIfPresent(Set<Int>.self, forKey: .workdays)
            ?? fallback.workdays
        halfDays = try container.decodeIfPresent(Set<Int>.self, forKey: .halfDays)
            ?? fallback.halfDays
        currencySymbol = try container.decodeIfPresent(String.self, forKey: .currencySymbol)
            ?? fallback.currencySymbol
        fractionDigits = try container.decodeIfPresent(Int.self, forKey: .fractionDigits)
            ?? fallback.fractionDigits
        language = try container.decodeIfPresent(String.self, forKey: .language)
            ?? fallback.language
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
        dayOverrides = try container.decodeIfPresent([String: String].self, forKey: .dayOverrides)
            ?? fallback.dayOverrides
        goals = try container.decodeIfPresent([SavingsGoalDTO].self, forKey: .goals) ?? []
        menuBarShowsProgressRing = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowsProgressRing)
            ?? fallback.menuBarShowsProgressRing
        menuBarShowsCurrencySymbol = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowsCurrencySymbol)
            ?? fallback.menuBarShowsCurrencySymbol
        menuBarIconOnlyWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .menuBarIconOnlyWhenIdle)
            ?? fallback.menuBarIconOnlyWhenIdle
        overtimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .overtimeEnabled)
            ?? fallback.overtimeEnabled
        overtimeMultiplier = try container.decodeIfPresent(Double.self, forKey: .overtimeMultiplier)
            ?? fallback.overtimeMultiplier
        overtimeMaxHours = try container.decodeIfPresent(Int.self, forKey: .overtimeMaxHours)
            ?? fallback.overtimeMaxHours
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled)
            ?? fallback.launchAtLoginEnabled
    }
}
