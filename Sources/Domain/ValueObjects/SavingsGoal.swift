import Foundation

/// Something the user wants to buy, priced in work rather than money.
public struct SavingsGoal: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var amount: Double
    /// Whether it appears in the menu bar panel. Everything else lives in Settings only,
    /// because the panel is small and a list of ten goals would bury the day's number.
    public var isPinned: Bool
    /// The instant saving for it began. Only earnings after this moment count towards it.
    ///
    /// The instant, not the day: a goal added at five in the afternoon must not arrive
    /// already paid for out of the morning's work.
    ///
    /// Stored rather than a running total, so the progress stays a pure function of the
    /// schedule and cannot drift the way an accumulated counter would.
    public var startedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        isPinned: Bool = true,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isPinned = isPinned
        self.startedAt = startedAt
    }

    public var isValid: Bool {
        amount > 0 && amount.isFinite && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// What a goal costs, in the two units that actually mean something.
public struct GoalProjection: Equatable, Sendable {
    /// Paid seconds of work the goal is worth. Fixed — this is the price in life.
    public let workSeconds: TimeInterval
    /// The same thing in whole working days plus a remainder, for display.
    public let workdays: Double
    /// Earned towards it so far, counting from the day saving began.
    public let earned: Double
    /// 0...1 of the way there.
    public let progress: Double
    /// When the schedule says the rest of it will be paid for.
    ///
    /// Holds still while the schedule holds still: the money and the clock advance
    /// together, so working simply keeps the promise rather than moving it. It slips only
    /// when the schedule itself changes — leave marked, a workday dropped, hours shortened.
    ///
    /// Nil when it is further out than the projection is willing to look, or when the
    /// configuration earns nothing at all.
    public let readyAt: Date?

    public init(
        workSeconds: TimeInterval,
        workdays: Double,
        earned: Double,
        progress: Double,
        readyAt: Date?
    ) {
        self.workSeconds = workSeconds
        self.workdays = workdays
        self.earned = earned
        self.progress = progress
        self.readyAt = readyAt
    }

    public static let unreachable = GoalProjection(
        workSeconds: 0, workdays: 0, earned: 0, progress: 0, readyAt: nil
    )
}
