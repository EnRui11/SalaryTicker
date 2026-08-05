import Foundation

/// Where the user's configuration comes from and goes to.
///
/// The domain states the contract; the data layer decides that it happens to be JSON in
/// `UserDefaults`. Neither the calculator nor the UI knows the difference.
public protocol SettingsRepository: Sendable {
    /// Never fails: a missing or unreadable store yields the defaults.
    func load() -> SalaryConfig
    func save(_ config: SalaryConfig)
}
