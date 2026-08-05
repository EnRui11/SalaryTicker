import Foundation

/// Where the clock currently sits relative to the configured schedule.
public enum WorkStatus: Equatable, Sendable {
    case dayOff
    case beforeWork(startsIn: TimeInterval)
    case working(endsIn: TimeInterval)
    case lunch(endsIn: TimeInterval)
    case afterWork
    /// Past clock-off and still counting, with overtime enabled.
    case overtime(elapsed: TimeInterval)
    /// The schedule cannot produce a rate (zero salary, zero paid minutes, no workdays).
    case misconfigured

    /// Whether the number is currently moving.
    ///
    /// Everything else is a frozen value, which is worth knowing: there is no reason to
    /// wake up and redraw the menu bar once a second all evening and all weekend.
    public var isAccruing: Bool {
        switch self {
        case .working, .lunch, .overtime: true
        case .dayOff, .beforeWork, .afterWork, .misconfigured: false
        }
    }
}

/// A full snapshot of "right now", recomputed from scratch on every tick.
public struct Earnings: Equatable, Sendable {
    public var todayEarned: Double
    public var dailyPay: Double
    public var hourlyPay: Double
    public var ratePerSecond: Double
    /// Overtime seconds accrued today, already capped.
    public var overtimeSeconds: TimeInterval
    /// The overtime slice of `todayEarned`.
    public var overtimeEarned: Double
    /// Everything earned this calendar month: finished working days plus today so far.
    public var monthEarned: Double
    /// Working days in the current calendar month, derived from the weekday selection.
    public var workdaysThisMonth: Int
    /// Working days of this month already finished, today excluded.
    public var workdaysCompletedThisMonth: Int
    /// Scheduled days this month marked as holiday or leave.
    public var daysOffThisMonth: Int
    /// Paid seconds worked so far today.
    public var elapsedPaidSeconds: TimeInterval
    public var totalPaidSeconds: TimeInterval
    /// 0...1 through the paid portion of the day.
    public var progress: Double
    public var status: WorkStatus

    public init(
        todayEarned: Double,
        dailyPay: Double,
        hourlyPay: Double,
        ratePerSecond: Double,
        overtimeSeconds: TimeInterval = 0,
        overtimeEarned: Double = 0,
        monthEarned: Double,
        workdaysThisMonth: Int,
        workdaysCompletedThisMonth: Int,
        daysOffThisMonth: Int = 0,
        elapsedPaidSeconds: TimeInterval,
        totalPaidSeconds: TimeInterval,
        progress: Double,
        status: WorkStatus
    ) {
        self.todayEarned = todayEarned
        self.dailyPay = dailyPay
        self.hourlyPay = hourlyPay
        self.ratePerSecond = ratePerSecond
        self.overtimeSeconds = overtimeSeconds
        self.overtimeEarned = overtimeEarned
        self.monthEarned = monthEarned
        self.workdaysThisMonth = workdaysThisMonth
        self.workdaysCompletedThisMonth = workdaysCompletedThisMonth
        self.daysOffThisMonth = daysOffThisMonth
        self.elapsedPaidSeconds = elapsedPaidSeconds
        self.totalPaidSeconds = totalPaidSeconds
        self.progress = progress
        self.status = status
    }

    /// The zero state, used before a valid configuration exists.
    public static let misconfigured = Earnings(
        todayEarned: 0, dailyPay: 0, hourlyPay: 0, ratePerSecond: 0,
        monthEarned: 0, workdaysThisMonth: 0, workdaysCompletedThisMonth: 0,
        elapsedPaidSeconds: 0, totalPaidSeconds: 0, progress: 0,
        status: .misconfigured
    )
}
