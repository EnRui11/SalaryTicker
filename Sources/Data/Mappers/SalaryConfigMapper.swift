import Foundation
import SalaryDomain

extension SalaryConfigDTO {
    init(_ config: SalaryConfig) {
        monthlySalary = config.monthlySalary
        workStart = TimeOfDayDTO(config.workStart)
        workEnd = TimeOfDayDTO(config.workEnd)
        lunchEnabled = config.lunchEnabled
        lunchStart = TimeOfDayDTO(config.lunchStart)
        lunchEnd = TimeOfDayDTO(config.lunchEnd)
        workdays = config.workdays
        halfDays = config.halfDays
        currencySymbol = config.currencySymbol
        fractionDigits = config.fractionDigits
        language = config.language.rawValue
        timeZoneIdentifier = config.timeZoneIdentifier
        dayOverrides = Dictionary(
            uniqueKeysWithValues: config.dayOverrides.map { ($0.key.raw, $0.value.rawValue) }
        )
        goals = config.goals.map {
            SavingsGoalDTO(
                id: $0.id.uuidString, name: $0.name, amount: $0.amount,
                isPinned: $0.isPinned, startedAt: $0.startedAt.timeIntervalSince1970
            )
        }
        menuBarShowsProgressRing = config.menuBarShowsProgressRing
        menuBarShowsCurrencySymbol = config.menuBarShowsCurrencySymbol
        menuBarIconOnlyWhenIdle = config.menuBarIconOnlyWhenIdle
        overtimeEnabled = config.overtimeEnabled
        overtimeMultiplier = config.overtimeMultiplier
        overtimeMaxHours = config.overtimeMaxHours
        launchAtLoginEnabled = config.launchAtLoginEnabled
    }

    /// An unrecognised language on disk degrades to the default rather than failing the load.
    func toDomain() -> SalaryConfig {
        SalaryConfig(
            monthlySalary: monthlySalary,
            workStart: workStart.toDomain(),
            workEnd: workEnd.toDomain(),
            lunchEnabled: lunchEnabled,
            lunchStart: lunchStart.toDomain(),
            lunchEnd: lunchEnd.toDomain(),
            workdays: workdays,
            halfDays: halfDays,
            currencySymbol: currencySymbol,
            fractionDigits: fractionDigits,
            language: AppLanguage(rawValue: language) ?? SalaryConfig.default.language,
            timeZoneIdentifier: timeZoneIdentifier,
            dayOverrides: Dictionary(
                uniqueKeysWithValues: dayOverrides.compactMap { raw, value in
                    // A malformed key or an override from a newer build is dropped rather
                    // than failing the whole load.
                    guard let key = DayKey(raw: raw), let override = DayOverride(rawValue: value)
                    else { return nil }
                    return (key, override)
                }
            ),
            goals: goals.compactMap { dto in
                // A goal whose id no longer parses is dropped rather than failing the load
                // and costing the user every other setting they have.
                guard let id = UUID(uuidString: dto.id) else { return nil }
                return SavingsGoal(
                    id: id, name: dto.name, amount: dto.amount, isPinned: dto.isPinned,
                    startedAt: Date(timeIntervalSince1970: dto.startedAt)
                )
            },
            menuBarShowsProgressRing: menuBarShowsProgressRing,
            menuBarShowsCurrencySymbol: menuBarShowsCurrencySymbol,
            menuBarIconOnlyWhenIdle: menuBarIconOnlyWhenIdle,
            overtimeEnabled: overtimeEnabled,
            overtimeMultiplier: overtimeMultiplier,
            overtimeMaxHours: overtimeMaxHours,
            launchAtLoginEnabled: launchAtLoginEnabled
        )
    }
}

extension SalaryConfigDTO.TimeOfDayDTO {
    init(_ time: TimeOfDay) {
        hour = time.hour
        minute = time.minute
    }

    func toDomain() -> TimeOfDay {
        TimeOfDay(hour, minute)
    }
}
