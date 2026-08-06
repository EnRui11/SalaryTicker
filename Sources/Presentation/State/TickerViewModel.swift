import Foundation
import Observation
import SalaryDomain
import SalaryApplication
import SalaryCore

/// Presentation state: holds the config the UI edits and the latest snapshot to draw.
///
/// It owns no business logic — every question goes to a use case. It holds no running
/// total either, so there is nothing to stop outside working hours and nothing to reset
/// at midnight.
///
/// It does hold caches, and those are the reason this type lives in a library target
/// rather than in the executable: they are keyed on the current day, so they are only
/// wrong once a day, at an hour nobody is watching.
@MainActor
@Observable
public final class TickerViewModel {

    public var config: SalaryConfig
    public private(set) var earnings: Earnings
    /// The month grid shown in Settings, for whichever month is being browsed.
    public private(set) var monthOverview: MonthOverview
    /// Months away from the current one. 0 is this month; the grid can be paged either way.
    public private(set) var monthOffset = 0
    /// Hourly rate for the month on screen, which is not always the current one — a month
    /// with more working days pays less per day, and that is worth seeing before you plan
    /// leave into it.
    public private(set) var displayedHourlyPay: Double = 0
    /// The month sweep behind the numbers. Same lifetime as the grid: it only changes when
    /// the day rolls over or the settings do, so the ticker reuses it instead of walking
    /// the month once a second.
    private var monthTotals: SalaryConfig.MonthTotals

    private let container: AppContainer
    private let clock: any TimeSource
    private var tickTask: Task<Void, Never>?

    // Recomputing the grid means ~31 calendar operations. `earnings` changes every second,
    // which re-renders the settings form, which would rebuild the grid every second for a
    // month that has not moved. Keyed on the only two things that can change it.
    private var overviewConfig: SalaryConfig?
    private var overviewDay: Date?
    private var overviewOffset = 0

    public init(container: AppContainer = AppContainer(), clock: any TimeSource = SystemTimeSource()) {
        self.container = container
        self.clock = clock
        let now = clock.now
        let loaded = container.loadSettings()
        self.config = loaded
        self.earnings = container.calculateEarnings(config: loaded, at: now)
        self.monthOverview = loaded.monthOverview(for: now, now: now, calendar: loaded.calendar())
        self.monthTotals = loaded.monthTotals(for: now, calendar: loaded.calendar())
        self.displayedHourlyPay = loaded.hourlyPay(at: now, calendar: loaded.calendar())

        // Make the system match what the user asked for. Only ever registers — see
        // `SetLaunchAtLoginUseCase.reconcile`.
        container.setLaunchAtLogin.reconcile(desired: loaded.launchAtLoginEnabled)
    }

    // MARK: Ticking

    public func start() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                // A second between redraws while the number is moving; a much longer nap
                // when it is frozen, which is most evenings and every weekend. Tolerance
                // lets the system coalesce our wakeups with others on top of that.
                let accruing = self?.earnings.status.isAccruing ?? true
                try? await Task.sleep(
                    for: accruing ? .seconds(1) : .seconds(20),
                    tolerance: accruing ? .milliseconds(250) : .seconds(5)
                )
            }
        }
    }

    public func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    public func refresh() {
        let now = clock.now
        refreshMonthOverviewIfNeeded(at: now)
        earnings = container.calculateEarnings(config: config, at: now, monthTotals: monthTotals)

        refreshGoals(at: now)
    }

    private func refreshGoals(at now: Date) {
        let calendar = config.calendar()
        let today = calendar.startOfDay(for: now)
        // Every valid goal, not only the pinned ones. Settings lists them all and asks each
        // for a projection on every redraw — which is once a second, since `earnings`
        // changes every tick and rebuilds the form — and an uncached projection for an old
        // goal costs tens of milliseconds.
        let valid = config.goals.filter(\.isValid)

        if goalCacheDay != today || goalCacheConfig != config {
            goalCache = Dictionary(uniqueKeysWithValues: valid.map { goal in
                let banked = GoalCalculator.earnedBeforeToday(
                    for: goal, config: config, now: now, calendar: calendar
                )
                let projection = GoalCalculator.projection(
                    for: goal, config: config, now: now,
                    earnedBeforeToday: banked, calendar: calendar
                )
                return (goal.id, (banked, projection))
            })
            goalCacheDay = today
            goalCacheConfig = config
        }

        pinnedGoals = valid
            .filter(\.isPinned)
            .compactMap { goal in
                liveProjection(for: goal, at: now, calendar: calendar).map { (goal, $0) }
            }
    }

    /// A cached projection with today's running total patched in.
    ///
    /// Everything expensive in a projection — the walk back over every day since saving
    /// started, and the walk forward to the day it lands on — is fixed for the whole day.
    /// Only the running total moves, and that is cheap.
    private func liveProjection(
        for goal: SavingsGoal, at now: Date, calendar: Calendar
    ) -> GoalProjection? {
        guard let cached = goalCache[goal.id] else { return nil }
        let earned = min(
            cached.banked + GoalCalculator.earnedToday(
                for: goal, config: config, now: now, calendar: calendar
            ),
            goal.amount
        )
        return GoalProjection(
            workSeconds: cached.projection.workSeconds,
            workdays: cached.projection.workdays,
            earned: earned,
            progress: goal.amount > 0 ? min(max(earned / goal.amount, 0), 1) : 0,
            readyAt: cached.projection.readyAt
        )
    }

    /// Rebuilds the grid only when the month it draws could actually have changed.
    private func refreshMonthOverviewIfNeeded(at now: Date) {
        let calendar = config.calendar()
        let today = calendar.startOfDay(for: now)
        guard overviewDay != today || overviewConfig != config || overviewOffset != monthOffset
        else { return }

        monthOverview = config.monthOverview(
            for: displayedMonth(at: now, calendar: calendar), now: now, calendar: calendar
        )
        // The totals behind the ticker always describe *this* month, however far the grid
        // has been paged away from it.
        monthTotals = config.monthTotals(for: now, calendar: calendar)
        displayedHourlyPay = config.hourlyPay(
            at: displayedMonth(at: now, calendar: calendar), calendar: calendar
        )
        overviewDay = today
        overviewConfig = config
        overviewOffset = monthOffset
    }

    private func displayedMonth(at now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
    }

    /// The first instant of the month currently on screen, for the grid's title.
    public var displayedMonthDate: Date {
        displayedMonth(at: clock.now, calendar: config.calendar())
    }

    public var isShowingCurrentMonth: Bool { monthOffset == 0 }

    public func stepMonth(by delta: Int) {
        // Two years either way is plenty for marking leave, and keeps a stuck arrow key
        // from wandering into the year 3000.
        monthOffset = min(max(monthOffset + delta, -24), 24)
        refresh()
    }

    public func showCurrentMonth() {
        monthOffset = 0
        refresh()
    }

    // MARK: Goals

    /// Projections for the goals pinned to the panel, refreshed with the tick.
    public private(set) var pinnedGoals: [(goal: SavingsGoal, projection: GoalProjection)] = []

    // Only two things in a projection are expensive, and neither moves within a day: the
    // walk back over every day since saving started, and the walk forward to the date it
    // lands on. Left uncached they cost milliseconds *per goal per second*, and they grow
    // with the goal's age — an old goal would quietly heat the machine up over months.
    private var goalCache: [SavingsGoal.ID: (banked: Double, projection: GoalProjection)] = [:]
    private var goalCacheConfig: SalaryConfig?
    private var goalCacheDay: Date?

    /// The projection Settings shows beside each goal.
    ///
    /// Served from the same day-keyed cache the panel uses, and computed from scratch only
    /// when the cache cannot answer — an edit the tick has not caught up with, or a goal
    /// that has only just become valid. The cached answer is used only when it was built
    /// for the configuration currently on screen, so an edit never sees a stale figure.
    public func projection(for goal: SavingsGoal) -> GoalProjection {
        let now = clock.now
        let calendar = config.calendar()
        if goalCacheConfig == config,
           let cached = liveProjection(for: goal, at: now, calendar: calendar) {
            return cached
        }
        return GoalCalculator.projection(for: goal, config: config, now: now, calendar: calendar)
    }

    public func addGoal() {
        config.goals.append(SavingsGoal(name: "", amount: 0, isPinned: true, startedAt: clock.now))
        configChanged()
    }

    public func removeGoal(_ id: SavingsGoal.ID) {
        config.goals.removeAll { $0.id == id }
        configChanged()
    }

    /// Cycles a day between working, paid leave and unpaid leave. Works on any month the
    /// grid is showing, not just the current one.
    public func cycleDayOverride(_ key: DayKey) {
        let next = DayOverride.next(after: config.dayOverrides[key])
        config.dayOverrides[key] = next
        configChanged()
    }

    /// Call after any edit in Settings: persist and reflect it in the menu bar immediately.
    public func configChanged() {
        container.saveSettings(config)
        refresh()
    }

    // MARK: Launch at login

    public var isLaunchAtLoginSupported: Bool { container.setLaunchAtLogin.isSupported }

    public func setLaunchAtLogin(_ enabled: Bool) -> Result<LoginItemState, any Error> {
        container.setLaunchAtLogin(enabled)
    }
}
