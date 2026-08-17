import Foundation
import Testing
import SalaryDomain
@testable import SalaryApplication

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
    return c
}

/// August 2026: the 3rd is a Monday, the 8th and 9th a weekend.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var parts = DateComponents()
    parts.year = 2026; parts.month = 8; parts.day = day
    parts.hour = hour; parts.minute = minute
    return cal().date(from: parts)!
}

/// 09:00–18:00, unpaid noon hour, Mon–Fri.
private let config = SalaryConfig(monthlySalary: 10_000, timeZoneIdentifier: "Asia/Kuala_Lumpur")

private func window(_ now: Date) -> ShiftWindow? {
    ShiftWindow.current(config: config, at: now, calendar: cal())
}

// A Live Activity cannot run code, so the only things on it that move by themselves are the
// ones iOS animates from a date range: a countdown and a progress bar. Handing those the
// right range is the whole job, and it is arithmetic, which means it can be tested even
// though nothing about the Dynamic Island itself can.

@Test func aShiftInProgressReportsItsOwnStartAndEnd() throws {
    let shift = try #require(window(at(3, 10)))
    #expect(shift.start == at(3, 9))
    #expect(shift.end == at(3, 18))
    #expect(shift.isRunning)
}

@Test func theRangeIsTheWholeShiftRatherThanWhatIsLeftOfIt() throws {
    // The system fills the bar across the range it is given, so it has to be the shift, not
    // now-to-clock-off. Handing it the remainder would restart the bar at zero every time
    // the activity was updated.
    let early = try #require(window(at(3, 10)))
    let late = try #require(window(at(3, 17)))
    #expect(early.start == late.start)
    #expect(early.end == late.end)
}

@Test func beforeWorkPointsAtTodaysShiftRatherThanCallingItOver() throws {
    let shift = try #require(window(at(3, 7)))
    #expect(shift.start == at(3, 9))
    #expect(shift.isRunning == false)
}

@Test func afterClockOffPointsAtTheNextOne() throws {
    let shift = try #require(window(at(3, 19)))
    #expect(shift.start == at(4, 9))
    #expect(shift.isRunning == false)
}

@Test func aWeekendPointsAtMonday() throws {
    let shift = try #require(window(at(8, 12)))
    #expect(shift.start == at(10, 9))
}

@Test func aScheduleThatEarnsNothingHasNoWindowRatherThanAnEmptyOne() {
    var broken = config
    broken.workdays = []
    #expect(ShiftWindow.current(config: broken, at: at(3, 10), calendar: cal()) == nil)
}

@Test func theRangeIsNeverEmptyWhichWouldDivideByZeroInTheProgressBar() throws {
    for hour in [7, 9, 12, 15, 18, 22] {
        let shift = try #require(window(at(3, hour)))
        #expect(shift.end > shift.start, "at \(hour):00")
    }
}
