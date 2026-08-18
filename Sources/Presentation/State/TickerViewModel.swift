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
        // In the order the user put them in: that order *is* the funding priority, so it
        // must not be filtered or sorted on the way through.
        let valid = config.goals.filter(\.isValid)

        if goalCacheDay != today || goalCacheConfig != config {
            // The expensive half — one calendar walk per distinct start instant, not per
            // goal, and only once a day. Goals created in the same click share a walk.
            bankedSinceStart = Dictionary(
                uniqueKeysWithValues: Set(valid.map(\.startedAt)).map { start in
                    (start, GoalCalculator.earnedBeforeToday(
                        since: start, config: config, now: now, calendar: calendar
                    ))
                }
            )
            goalCacheDay = today
            goalCacheConfig = config
        }

        // One allocation for the whole list. Goals compete for the same money, so none of
        // them can be projected alone without lying about the others.
        let projected = GoalCalculator.projections(
            for: valid, config: config, now: now,
            bankedSinceStart: bankedSinceStart, calendar: calendar
        )
        goalProjections = Dictionary(uniqueKeysWithValues: zip(valid.map(\.id), projected))
        pinnedGoals = zip(valid, projected)
            .filter { $0.0.isPinned }
            .map { (goal: $0.0, projection: $0.1) }
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

    // The expensive part of a projection is the walk back over every day since saving
    // started, and it does not move within a day. Left on the tick it costs milliseconds
    // per goal per second and grows with the goal's age, so an old goal would quietly heat
    // the machine up over months. Keyed on the start instant rather than the goal, because
    // the instant is what the walk actually depends on.
    private var bankedSinceStart: [Date: Double] = [:]
    private var goalProjections: [SavingsGoal.ID: GoalProjection] = [:]
    private var goalCacheConfig: SalaryConfig?
    private var goalCacheDay: Date?

    /// The projection Settings shows beside each goal.
    ///
    /// Read out of the allocation the tick already made. If the configuration has moved on
    /// since — an edit SwiftUI rendered before `configChanged` ran — the whole list is
    /// re-allocated once, not once per row.
    public func projection(for goal: SavingsGoal) -> GoalProjection {
        if goalCacheConfig != config { refreshGoals(at: clock.now) }
        return goalProjections[goal.id] ?? .unreachable
    }

    /// Reorders the goals, which is the same act as reprioritising them: money fills the
    /// top of the list first, and a goal only starts filling once those above it are full.
    ///
    /// Written out rather than calling `move(fromOffsets:toOffset:)`, which SwiftUI adds:
    /// this target has no business importing a UI framework to reorder an array.
    public func moveGoals(from source: IndexSet, to destination: Int) {
        let indices = source.sorted().filter { config.goals.indices.contains($0) }
        guard !indices.isEmpty else { return }

        let moving = indices.map { config.goals[$0] }
        var reordered = config.goals
        for index in indices.reversed() { reordered.remove(at: index) }

        // `destination` indexes the list as it looked *before* anything was taken out of it.
        let taken = indices.filter { $0 < destination }.count
        let insertAt = min(max(destination - taken, 0), reordered.count)
        reordered.insert(contentsOf: moving, at: insertAt)

        config.goals = reordered
        configChanged()
    }

    public func addGoal() {
        config.goals.append(SavingsGoal(name: "", amount: 0, isPinned: true, startedAt: clock.now))
        configChanged()
    }

    /// Adds a goal that is already finished being described.
    ///
    /// The no-argument version appends a blank for the user to fill in, which works on a
    /// surface that shows every goal including the unfinished ones. The phone's main screen
    /// is not that surface -- it shows only goals that are `isValid` -- so a blank appended
    /// there is written to disk and then displayed nowhere, and tapping the button again
    /// silently writes another. This one collects the details first and appends once.
    ///
    /// `startedAt` is stamped here rather than by the caller so it comes from the injected
    /// clock: a goal must not be able to claim work done before it existed.
    public func addGoal(name: String, amount: Double, isPinned: Bool = true) {
        config.goals.append(
            SavingsGoal(name: name, amount: amount, isPinned: isPinned, startedAt: clock.now)
        )
        configChanged()
    }

    public func removeGoal(_ id: SavingsGoal.ID) {
        config.goals.removeAll { $0.id == id }
        configChanged()
    }

    /// One step up the list, and one step down.
    ///
    /// Dragging is the nice way to do this, but a goal row is two text fields, a checkbox
    /// and a delete button — there is almost no dead space in it to press on, and whether
    /// the drag lands at all depends on the platform. These always work.
    public func moveGoalUp(_ id: SavingsGoal.ID) {
        guard let index = config.goals.firstIndex(where: { $0.id == id }), index > 0 else { return }
        moveGoals(from: IndexSet(integer: index), to: index - 1)
    }

    public func moveGoalDown(_ id: SavingsGoal.ID) {
        guard let index = config.goals.firstIndex(where: { $0.id == id }),
              index < config.goals.count - 1 else { return }
        // Two, not one: `moveGoals` reads its destination against the list as it was before
        // anything was lifted out of it, so one step down is an insertion two places along.
        moveGoals(from: IndexSet(integer: index), to: index + 2)
    }

    /// Where a goal sits in the funding queue, for the controls that move it.
    public func position(of id: SavingsGoal.ID) -> (index: Int, count: Int)? {
        guard let index = config.goals.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, config.goals.count)
    }

    /// Cycles a day between working, paid leave and unpaid leave. Works on any month the
    /// grid is showing, not just the current one.
    public func cycleDayOverride(_ key: DayKey) {
        let next = DayOverride.next(after: config.dayOverrides[key])
        config.dayOverrides[key] = next
        configChanged()
    }

    /// Take the amount out of the menu bar, or put it back.
    ///
    /// Persisted like any other setting: quitting with it hidden and relaunching to find
    /// the number back on screen would defeat the point of having hidden it.
    public func toggleMenuBarAmount() {
        config.menuBarHidesAmount.toggle()
        configChanged()
    }

    /// Call after any edit in Settings: persist and reflect it in the menu bar immediately.
    public func configChanged() {
        container.saveSettings(config)
        refresh()
    }

    // MARK: Moving the settings between machines

    /// The link that carries this configuration to a phone. The Mac draws it as a QR code.
    ///
    /// It contains your salary. It never leaves the machine as long as it stays a picture
    /// on screen and goes into a camera; copied out as text it deserves the same care as a
    /// payslip.
    public var shareLink: URL { container.configLink.url(for: config) }

    /// What an arriving link would set, without setting it.
    ///
    /// Separate from applying it on purpose: importing replaces every setting at once, so
    /// the user gets to see the salary and the hours before agreeing to them.
    public func configuration(fromLink url: URL) -> SalaryConfig? {
        container.configLink.config(from: url)
    }

    /// Takes an arriving configuration, except for the parts that are about this device.
    ///
    /// Importing replaces everything, which is the point -- the salary and the schedule are
    /// what was worth carrying across. `liveActivityEnabled` is the one field that breaks
    /// that rule, because the device that sent it has no Dynamic Island to have an opinion
    /// about: a Mac's copy of this flag is whatever the default happened to be, and taking
    /// it would silently switch the phone's island back on after the user turned it off.
    public func apply(_ imported: SalaryConfig) {
        var incoming = imported
        incoming.liveActivityEnabled = config.liveActivityEnabled
        config = incoming
        configChanged()
    }

    // MARK: Launch at login

    public var isLaunchAtLoginSupported: Bool { container.setLaunchAtLogin.isSupported }

    public func setLaunchAtLogin(_ enabled: Bool) -> Result<LoginItemState, any Error> {
        container.setLaunchAtLogin(enabled)
    }
}
