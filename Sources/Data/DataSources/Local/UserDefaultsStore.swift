import Foundation

/// The only place that touches `UserDefaults`.
///
/// `@unchecked Sendable`: `UserDefaults` is documented as thread-safe but predates the
/// concurrency annotations, and this type adds no mutable state of its own.
struct UserDefaultsStore: @unchecked Sendable {
    enum Key {
        static let salaryConfig = "salaryConfig"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}
