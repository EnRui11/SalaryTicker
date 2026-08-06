import Foundation
import SalaryDomain

/// A clock the test moves by hand.
///
/// Unchecked because the tests drive it from the main actor only; making it an actor would
/// force every assertion through an await for no gain in coverage.
final class FakeClock: TimeSource, @unchecked Sendable {
    var now: Date

    init(_ now: Date) { self.now = now }

    func advance(to instant: Date) { now = instant }
}

/// Settings that never touch `UserDefaults`, and count how often they were written.
///
/// The count matters: "the app saved my change" is not observable from the config alone,
/// because the in-memory copy would look right either way.
final class InMemorySettings: SettingsRepository, @unchecked Sendable {
    var stored: SalaryConfig
    private(set) var saveCount = 0

    init(_ stored: SalaryConfig) { self.stored = stored }

    func load() -> SalaryConfig { stored }

    func save(_ config: SalaryConfig) {
        stored = config
        saveCount += 1
    }
}

/// A login item that records what was asked of it.
final class FakeLoginItem: LoginItemService, @unchecked Sendable {
    var isSupported: Bool
    var state: LoginItemState
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(isSupported: Bool = true, state: LoginItemState = .notRegistered) {
        self.isSupported = isSupported
        self.state = state
    }

    func register() throws {
        registerCount += 1
        state = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        state = .notRegistered
    }
}
