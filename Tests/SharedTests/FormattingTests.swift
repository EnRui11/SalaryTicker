import Foundation
import Testing
@testable import SalaryShared
import SalaryDomain

private func earnings(_ status: WorkStatus, earned: Double = 12.0) -> Earnings {
    Earnings(
        todayEarned: earned, dailyPay: 0, hourlyPay: 0, ratePerSecond: 0,
        monthEarned: 0, workdaysThisMonth: 21, workdaysCompletedThisMonth: 2,
        elapsedPaidSeconds: 0, totalPaidSeconds: 0, progress: 0, status: status
    )
}

@Test func moneyKeepsAFixedWidthSoTheMenuBarDoesNotJitter() {
    let config = SalaryConfig()
    #expect(Formatting.money(0, config: config) == "$0.0000")
    #expect(Formatting.money(1.5, config: config) == "$1.5000")
    #expect(Formatting.money(12.34567, config: config) == "$12.3457")
    // Same integer digit count → same character count.
    #expect(Formatting.money(11.1, config: config).count == Formatting.money(88.8, config: config).count)
}

@Test func moneySurvivesNonFiniteInput() {
    let config = SalaryConfig()
    #expect(Formatting.money(.nan, config: config) == "$0.0000")
    #expect(Formatting.money(.infinity, config: config) == "$0.0000")
}

@Test func durationReadsNaturallyInEachLanguage() {
    #expect(Formatting.duration(45, Strings(.english)) == "45s")
    #expect(Formatting.duration(800, Strings(.english)) == "13m 20s")
    #expect(Formatting.duration(8000, Strings(.english)) == "2h 13m")
    #expect(Formatting.duration(-5, Strings(.english)) == "0s")

    #expect(Formatting.duration(45, Strings(.chinese)) == "45 秒")
    #expect(Formatting.duration(8000, Strings(.chinese)) == "2 小时 13 分")

    #expect(Formatting.duration(45, Strings(.malay)) == "45 saat")
    #expect(Formatting.duration(8000, Strings(.malay)) == "2 jam 13 min")
}

@Test func menuBarShowsStateInsteadOfAFrozenNumber() {
    let config = SalaryConfig()   // defaults to English
    func text(_ status: WorkStatus) -> String {
        Formatting.menuBarText(earnings(status), config: config)
    }

    #expect(text(.dayOff) == "Day off")
    #expect(text(.misconfigured) == "Set salary")
    #expect(text(.beforeWork(startsIn: 60)) == "$0.0000")
    #expect(text(.working(endsIn: 60)) == "$12.0000")
    #expect(text(.afterWork) == "$12.0000")   // frozen at the day's final value
}

@Test func theMenuBarFollowsTheConfiguredLanguage() {
    var config = SalaryConfig()
    config.language = .chinese
    #expect(Formatting.menuBarText(earnings(.dayOff), config: config) == "休息中")
    config.language = .malay
    #expect(Formatting.menuBarText(earnings(.dayOff), config: config) == "Cuti")
}

@Test func statusTextIsTranslatedEverywhere() {
    for language in AppLanguage.allCases {
        let strings = Strings(language)
        let all: [WorkStatus] = [
            .dayOff, .beforeWork(startsIn: 3600), .working(endsIn: 3600),
            .lunch(endsIn: 600), .afterWork, .misconfigured,
        ]
        for status in all {
            let rendered = Formatting.statusText(status, strings)
            #expect(!rendered.isEmpty, "\(language) \(status)")
            // Nothing may leak a hard-coded string from another language.
            if language != .chinese {
                #expect(!rendered.contains("小时"), "\(language) \(status) → \(rendered)")
                #expect(!rendered.contains("下班"), "\(language) \(status) → \(rendered)")
            }
        }
    }
}

// MARK: - Language coverage

/// Every string the UI can show, as a closure so the whole set can be swept per language.
private let allStrings: [(name: String, render: @Sendable (Strings) -> String)] = [
    ("earnedToday", { $0.earnedToday }), ("todayProgress", { $0.todayProgress }),
    ("perSecond", { $0.perSecond }), ("hourly", { $0.hourly }),
    ("fullDay", { $0.fullDay }), ("monthToDate", { $0.monthToDate }),
    ("plusToday", { $0.plusToday }), ("setupNotice", { $0.setupNotice }),
    ("settingsAction", { $0.settingsAction }), ("quitAction", { $0.quitAction }),
    ("dayOff", { $0.dayOff }), ("clockedOff", { $0.clockedOff }),
    ("setupIncomplete", { $0.setupIncomplete }),
    ("menuBarSetSalary", { $0.menuBarSetSalary }), ("menuBarDayOff", { $0.menuBarDayOff }),
    ("sectionSalary", { $0.sectionSalary }), ("monthlySalary", { $0.monthlySalary }),
    ("workdaysThisMonth", { $0.workdaysThisMonth }), ("derivedHourly", { $0.derivedHourly }),
    ("invalidNotice", { $0.invalidNotice }), ("salaryCaption", { $0.salaryCaption }),
    ("sectionSchedule", { $0.sectionSchedule }), ("clockIn", { $0.clockIn }),
    ("clockOff", { $0.clockOff }), ("unpaidLunch", { $0.unpaidLunch }),
    ("lunchStart", { $0.lunchStart }), ("lunchEnd", { $0.lunchEnd }),
    ("paidPerDay", { $0.paidPerDay }), ("overnightCaption", { $0.overnightCaption }),
    ("sectionWorkdays", { $0.sectionWorkdays }), ("sectionDisplay", { $0.sectionDisplay }),
    ("languageLabel", { $0.languageLabel }), ("timeZoneLabel", { $0.timeZoneLabel }),
    ("systemTimeZone", { $0.systemTimeZone }), ("timeZoneCaption", { $0.timeZoneCaption }),
    ("currencySymbol", { $0.currencySymbol }), ("decimals", { $0.decimals }),
    ("menuBarPreview", { $0.menuBarPreview }), ("sectionSystem", { $0.sectionSystem }),
    ("launchAtLogin", { $0.launchAtLogin }), ("notBundledCaption", { $0.notBundledCaption }),
    ("notBundledError", { $0.notBundledError }),
    ("hoursMinutes", { $0.hoursMinutes(2, 13) }), ("minutesSeconds", { $0.minutesSeconds(13, 20) }),
    ("seconds", { $0.seconds(45) }), ("days", { $0.days(21) }),
    ("workdaysDone", { $0.workdaysDone(2, 21) }), ("startsIn", { $0.startsIn("1h") }),
    ("untilClockOff", { $0.untilClockOff("1h") }), ("lunchLeft", { $0.lunchLeft("1h") }),
    ("sectionGeneral", { $0.sectionGeneral }), ("legendWorked", { $0.legendWorked }),
    ("legendUpcoming", { $0.legendUpcoming }), ("launchNeedsApproval", { $0.launchNeedsApproval }),
    ("sectionOvertime", { $0.sectionOvertime }), ("overtimeEnabled", { $0.overtimeEnabled }),
    ("overtimeRate", { $0.overtimeRate }), ("overtimeMax", { $0.overtimeMax }),
    ("overtimeCaption", { $0.overtimeCaption }), ("overtimeFor", { $0.overtimeFor("1h") }),
    ("hours", { $0.hours(4) }), ("today", { $0.today }),
    ("menuBarShowSymbol", { $0.menuBarShowSymbol }),
    ("menuBarIconWhenIdle", { $0.menuBarIconWhenIdle }),
    ("searchPlaceholder", { $0.searchPlaceholder }), ("changeAction", { $0.changeAction }),
    ("menuBarShowRing", { $0.menuBarShowRing }), ("previousMonth", { $0.previousMonth }),
    ("nextMonth", { $0.nextMonth }), ("backToThisMonth", { $0.backToThisMonth }),
    ("halfDay", { $0.halfDay }), ("weekdayHint", { $0.weekdayHint }),
    ("sectionGoals", { $0.sectionGoals }), ("goalNamePlaceholder", { $0.goalNamePlaceholder }),
    ("goalPrice", { $0.goalPrice }), ("addGoal", { $0.addGoal }),
    ("showInPanel", { $0.showInPanel }), ("noGoalsYet", { $0.noGoalsYet }),
    ("goalReached", { $0.goalReached }), ("goalOutOfReach", { $0.goalOutOfReach }),
    ("goalsCaption", { $0.goalsCaption }),
    ("workdaysCost", { $0.workdaysCost("2.1") }), ("readyBy", { $0.readyBy("Thu") }),
    ("calendarHint", { $0.calendarHint }), ("legendPaidLeave", { $0.legendPaidLeave }),
    ("legendUnpaidLeave", { $0.legendUnpaidLeave }), ("daysOff", { $0.daysOff(2) }),
]

@Test func noStringIsEmptyInAnyLanguage() {
    for language in AppLanguage.allCases {
        let strings = Strings(language)
        for entry in allStrings {
            #expect(!entry.render(strings).isEmpty, "\(language.rawValue).\(entry.name) is empty")
        }
    }
}

@Test func noStringIsLeftUntranslated() {
    // Catches the usual localisation rot: a string added in one language and pasted
    // unchanged into the others. Interpolated forms are skipped where several languages
    // legitimately share the same shape (\"2 h 13 min\" in both Spanish and French).
    let sharedByDesign: Set<String> = [
        "hoursMinutes", "minutesSeconds", "seconds", "days", "plusToday",
        "sectionSystem", "menuBarPreview", "startsIn", "untilClockOff", "lunchLeft",
        "workdaysDone", "systemTimeZone", "currencySymbol", "decimals", "timeZoneLabel",
        "sectionDisplay", "languageLabel", "hours", "sectionGeneral", "overtimeRate",
        "sectionOvertime", "overtimeFor", "daysOff",
    ]

    for entry in allStrings where !sharedByDesign.contains(entry.name) {
        let rendered = AppLanguage.allCases.map { entry.render(Strings($0)) }
        let distinct = Set(rendered)
        #expect(distinct.count >= AppLanguage.allCases.count - 1,
                "\(entry.name) looks copy-pasted across languages: \(rendered)")
    }
}

@Test func noLanguageLeaksAnotherLanguagesText() {
    // A missing translation used to show up as English (or worse, Chinese) inside an
    // otherwise localized screen.
    let markers: [(AppLanguage, [String])] = [
        (.chinese, ["小时", "下班", "月薪"]),
        (.japanese, ["時間", "退勤", "月給"]),
        (.korean, ["시간", "퇴근", "월급"]),
    ]

    for language in AppLanguage.allCases {
        let strings = Strings(language)
        for (owner, tokens) in markers where owner != language {
            for entry in allStrings {
                let rendered = entry.render(strings)
                for token in tokens {
                    #expect(!rendered.contains(token),
                            "\(language.rawValue).\(entry.name) leaked \(owner.rawValue): \(rendered)")
                }
            }
        }
    }
}

@Test func everyLanguageHasSevenWeekdayInitials() {
    for language in AppLanguage.allCases {
        #expect(Strings(language).weekdayInitials.count == 7)
    }
}

@Test func languageRoundTripsThroughItsRawValue() {
    for language in AppLanguage.allCases {
        #expect(AppLanguage(rawValue: language.rawValue) == language)
        #expect(!language.displayName.isEmpty)
        #expect(!language.localeIdentifier.isEmpty)
    }
}

// MARK: - Locale-aware money

@Test func moneyFollowsTheLanguagesNumberConventions() {
    // English groups with commas and puts the symbol first.
    #expect(Formatting.money(1234.5, symbol: "$", digits: 2, language: .english) == "$1,234.50")
    // German groups with dots, uses a decimal comma, and puts the symbol last.
    #expect(Formatting.money(1234.5, symbol: "$", digits: 2, language: .german) == "1.234,50\u{00A0}$")
    // French also trails the symbol.
    #expect(Formatting.money(1234.5, symbol: "€", digits: 2, language: .french).hasSuffix("€"))
    // Japanese leads it.
    #expect(Formatting.money(1234.5, symbol: "¥", digits: 2, language: .japanese).hasPrefix("¥"))
}

@Test func moneyStillSurvivesNonFiniteInputInEveryLanguage() {
    for language in AppLanguage.allCases {
        for bad in [Double.nan, .infinity, -.infinity] {
            let rendered = Formatting.money(bad, symbol: "$", digits: 2, language: language)
            #expect(!rendered.contains("nan"))
            #expect(!rendered.contains("inf"))
        }
    }
}

@Test func anEmptySymbolLeavesNoStraySpace() {
    #expect(Formatting.money(12.5, symbol: "", digits: 2, language: .german) == "12,50")
    #expect(Formatting.money(12.5, symbol: "", digits: 2, language: .english) == "12.50")
}

// MARK: - Menu bar content

private func config(_ mutate: (inout SalaryConfig) -> Void = { _ in }) -> SalaryConfig {
    var c = SalaryConfig()
    mutate(&c)
    return c
}

@Test func theMenuBarDropsTheSymbolWhenAskedTo() {
    let compact = config { $0.menuBarShowsCurrencySymbol = false }
    let shown = Formatting.menuBarText(earnings(.working(endsIn: 60)), config: compact)
    #expect(!shown.contains("$"))
    #expect(shown == "12.0000")
}

@Test func theMenuBarCollapsesToAnIconOutsideWorkingHours() {
    let idle = config { $0.menuBarIconOnlyWhenIdle = true }

    #expect(Formatting.menuBarContent(earnings(.dayOff), config: idle) == .icon)
    #expect(Formatting.menuBarContent(earnings(.afterWork), config: idle) == .icon)
    #expect(Formatting.menuBarContent(earnings(.beforeWork(startsIn: 60)), config: idle) == .icon)

    // Still earning — the number must stay.
    #expect(Formatting.menuBarContent(earnings(.working(endsIn: 60)), config: idle)
            == .text("$12.0000"))
    #expect(Formatting.menuBarContent(earnings(.lunch(endsIn: 60)), config: idle)
            == .text("$12.0000"))
    #expect(Formatting.menuBarContent(earnings(.overtime(elapsed: 60)), config: idle)
            == .text("$12.0000"))
}

@Test func theIconModeIsOffByDefault() {
    #expect(Formatting.menuBarContent(earnings(.dayOff), config: config()) == .text("Day off"))
}

@Test func overtimeHasItsOwnStatusLineInEveryLanguage() {
    for language in AppLanguage.allCases {
        let rendered = Formatting.statusText(.overtime(elapsed: 5400), Strings(language))
        #expect(!rendered.isEmpty)
        #expect(rendered != Formatting.statusText(.afterWork, Strings(language)))
    }
}

@Test func theMonthTitleFollowsTheLanguage() {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = 5
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    let august = calendar.date(from: parts)!

    #expect(Formatting.monthTitle(august, language: .english) == "August 2026")
    #expect(Formatting.monthTitle(august, language: .chinese).contains("8"))
    for language in AppLanguage.allCases {
        #expect(!Formatting.monthTitle(august, language: language).isEmpty)
    }
}

@Test func theDefaultCurrencySymbolIsTheDollar() {
    #expect(SalaryConfig.default.currencySymbol == "$")
}
