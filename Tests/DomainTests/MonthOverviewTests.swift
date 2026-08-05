import Foundation
import Testing
@testable import SalaryDomain

private func cal(_ zone: String = "Asia/Kuala_Lumpur") -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var parts = DateComponents()
    parts.year = year; parts.month = month; parts.day = day; parts.hour = 12
    return cal().date(from: parts)!
}

private let standard = SalaryConfig(monthlySalary: 10_000)   // Mon–Fri

@Test func theGridCoversTheWholeMonth() {
    let overview = standard.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal())
    #expect(overview.days.count == 31)
    #expect(overview.days.first?.day == 1)
    #expect(overview.days.last?.day == 31)
}

@Test func leadingBlanksLineTheFirstUpUnderItsWeekday() {
    // 2026-08-01 is a Saturday, so six blanks precede it in a Sunday-first grid.
    #expect(standard.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal()).leadingBlanks == 6)
    // 2026-02-01 is a Sunday: no blanks at all.
    #expect(standard.monthOverview(for: day(2026, 2, 10), now: day(2026, 2, 10), calendar: cal()).leadingBlanks == 0)
}

@Test func februaryHasTheRightNumberOfSquares() {
    // 2026 is not a leap year.
    #expect(standard.monthOverview(for: day(2026, 2, 10), now: day(2026, 2, 10), calendar: cal()).days.count == 28)
    // 2028 is.
    #expect(standard.monthOverview(for: day(2028, 2, 10), now: day(2028, 2, 10), calendar: cal()).days.count == 29)
}

@Test func workdaysMatchTheWeekdaySelection() {
    let overview = standard.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal())
    #expect(overview.workdayCount == 21)
    #expect(overview.days.filter(\.isWorkday).count == 21)

    // 2026-08-01 is a Saturday and 08-03 a Monday.
    #expect(overview.days[0].isWorkday == false)
    #expect(overview.days[2].isWorkday == true)
}

@Test func theCountsAgreeWithTheEarningsMath() {
    // The grid must never tell a different story from the number in the panel.
    let now = day(2026, 8, 5)
    let overview = standard.monthOverview(for: now, now: now, calendar: cal())
    #expect(overview.workdayCount == standard.workdaysInMonth(of: now, calendar: cal()))
    #expect(overview.completedWorkdayCount
            == standard.completedWorkdaysInMonth(before: now, calendar: cal()))
}

@Test func todayIsMarkedAndIsNotCountedAsCompleted() {
    let overview = standard.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal())
    let today = overview.days.first { $0.isToday }
    #expect(today?.day == 5)
    #expect(today?.isPast == false)
    #expect(overview.completedWorkdayCount == 2)   // the 3rd and 4th
}

@Test func changingTheWeekdaySelectionChangesTheGrid() {
    var weekendsToo = standard
    weekendsToo.workdays = [1, 2, 3, 4, 5, 6, 7]
    #expect(weekendsToo.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal()).workdayCount == 31)

    var mondaysOnly = standard
    mondaysOnly.workdays = [2]
    #expect(mondaysOnly.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal()).workdayCount == 5)
}

@Test func noWorkdaysSelectedStillProducesAReadableMonth() {
    var none = standard
    none.workdays = []
    let overview = none.monthOverview(for: day(2026, 8, 5), now: day(2026, 8, 5), calendar: cal())
    #expect(overview.days.count == 31)
    #expect(overview.workdayCount == 0)
    #expect(overview.completedWorkdayCount == 0)
}

@Test func theGridFollowsTheChosenTimeZone() {
    // Same instant, two zones that are on different calendar days.
    var parts = DateComponents()
    parts.year = 2026; parts.month = 9; parts.day = 1; parts.hour = 3
    let instant = cal().date(from: parts)!          // 2026-09-01 03:00 in Kuala Lumpur

    let here = standard.monthOverview(for: instant, now: instant, calendar: cal())
    let honolulu = standard.monthOverview(for: instant, now: instant, calendar: cal("Pacific/Honolulu"))

    #expect(here.days.count == 30)                   // September
    #expect(honolulu.days.count == 31)               // still August there
}

// MARK: - Browsing other months

@Test func browsingAnotherMonthMarksNoDayAsToday() {
    // The 5th of September is not "today" just because today is the 5th of August.
    let now = day(2026, 8, 5)
    let september = standard.monthOverview(for: day(2026, 9, 15), now: now, calendar: cal())

    #expect(september.days.count == 30)
    let marksToday = september.days.contains(where: { $0.isToday })
    #expect(marksToday == false)
}

@Test func aFutureMonthHasNothingInThePast() {
    let now = day(2026, 8, 5)
    let september = standard.monthOverview(for: day(2026, 9, 15), now: now, calendar: cal())
    let nothingPast = september.days.allSatisfy({ !$0.isPast })
    #expect(nothingPast)
    #expect(september.completedWorkdayCount == 0)
}

@Test func aPastMonthIsEntirelyBehindUs() {
    let now = day(2026, 8, 5)
    let july = standard.monthOverview(for: day(2026, 7, 15), now: now, calendar: cal())
    let allPast = july.days.allSatisfy({ $0.isPast })
    #expect(allPast)
    #expect(july.completedWorkdayCount == july.workdayCount)
}

@Test func leaveMarkedInAnotherMonthShowsUpThere() {
    var config = standard
    config.dayOverrides = [DayKey(year: 2026, month: 9, day: 7): .paidLeave]
    let now = day(2026, 8, 5)

    let august = config.monthOverview(for: now, now: now, calendar: cal())
    let september = config.monthOverview(for: day(2026, 9, 15), now: now, calendar: cal())

    #expect(august.daysOffCount == 0)
    #expect(september.daysOffCount == 1)
    let seventh = september.days.first(where: { $0.day == 7 })
    #expect(seventh?.override == .paidLeave)
}

@Test func aMonthAcrossAYearBoundaryStillLinesUp() {
    let now = day(2026, 12, 20)
    let january = standard.monthOverview(for: day(2027, 1, 10), now: now, calendar: cal())
    #expect(january.days.count == 31)
    #expect(january.days.first?.key == DayKey(year: 2027, month: 1, day: 1))
    let januaryAhead = january.days.allSatisfy({ !$0.isPast })
    #expect(januaryAhead)
}

@Test func aMonthWithMoreWorkingDaysPaysLessPerDay() {
    // What the settings page shows while the grid is paged forward: September 2026 has one
    // more Mon–Fri day than August, so the same salary buys a slightly cheaper hour.
    let august = day(2026, 8, 15)
    let september = day(2026, 9, 15)

    #expect(standard.workdaysInMonth(of: august, calendar: cal()) == 21)
    #expect(standard.workdaysInMonth(of: september, calendar: cal()) == 22)
    #expect(standard.hourlyPay(at: september, calendar: cal())
            < standard.hourlyPay(at: august, calendar: cal()))
    #expect(abs(standard.hourlyPay(at: september, calendar: cal()) - 10_000 / 22 / 8) < 1e-9)
}

@Test func markingLeaveInABrowsedMonthChangesThatMonthsRate() {
    // Leave marked ahead of time has to move the month it belongs to, not the current one.
    var planned = standard
    planned.dayOverrides = [DayKey(year: 2026, month: 9, day: 7): .paidLeave]

    let august = day(2026, 8, 15)
    let september = day(2026, 9, 15)

    #expect(planned.hourlyPay(at: august, calendar: cal())
            == standard.hourlyPay(at: august, calendar: cal()))
    #expect(planned.hourlyPay(at: september, calendar: cal())
            > standard.hourlyPay(at: september, calendar: cal()))
    #expect(planned.workdaysInMonth(of: september, calendar: cal()) == 21)
}
