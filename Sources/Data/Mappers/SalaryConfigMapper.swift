import Foundation
import SalaryDomain

extension SalaryConfigDTO {
    init(_ config: SalaryConfig) {
        monthlySalary = config.monthlySalary
        monthlyAllowance = config.monthlyAllowance
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
                isPinned: $0.isPinned,
                // Rounded to the second, and not for tidiness. A Date holds seconds since
                // 2001; the stored format holds seconds since 1970. Adding that offset and
                // subtracting it again loses the low bits, so a goal created now did not
                // survive a save and reload as an equal value — the difference was under a
                // nanosecond and enough to make two identical configurations compare
                // unequal. A start time to the second is more precision than the feature
                // has ever needed.
                startedAt: $0.startedAt.timeIntervalSince1970.rounded()
            )
        }
        menuBarShowsProgressRing = config.menuBarShowsProgressRing
        menuBarShowsCurrencySymbol = config.menuBarShowsCurrencySymbol
        menuBarIconOnlyWhenIdle = config.menuBarIconOnlyWhenIdle
        menuBarHidesAmount = config.menuBarHidesAmount
        overtimeEnabled = config.overtimeEnabled
        overtimeMultiplier = config.overtimeMultiplier
        overtimeMaxHours = config.overtimeMaxHours
        launchAtLoginEnabled = config.launchAtLoginEnabled
    }

    /// An unrecognised language on disk degrades to the default rather than failing the load.
    func toDomain() -> SalaryConfig {
        SalaryConfig(
            monthlySalary: monthlySalary,
            monthlyAllowance: monthlyAllowance,
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
            goals: goals.map { dto in
                // A goal whose id no longer parses keeps everything the user actually
                // typed and is given a fresh identity. Dropping it would once have been
                // the lesser evil against failing the whole load, but the decoder no
                // longer fails that way, so silently losing the goal buys nothing.
                SavingsGoal(
                    id: UUID(uuidString: dto.id) ?? UUID(),
                    name: dto.name, amount: dto.amount, isPinned: dto.isPinned,
                    startedAt: Date(timeIntervalSince1970: dto.startedAt)
                )
            },
            menuBarShowsProgressRing: menuBarShowsProgressRing,
            menuBarShowsCurrencySymbol: menuBarShowsCurrencySymbol,
            menuBarIconOnlyWhenIdle: menuBarIconOnlyWhenIdle,
            menuBarHidesAmount: menuBarHidesAmount,
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
