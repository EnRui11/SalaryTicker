import Foundation
import SalaryDomain

/// Stores the configuration as JSON in `UserDefaults`.
///
/// Both directions swallow failure on purpose: a settings file that cannot be read is not
/// worth refusing to launch over, and a config that cannot be encoded (an infinite salary
/// makes `JSONEncoder` throw) must not take the running app down with it. Either way the
/// user keeps a working menu bar.
public struct UserDefaultsSettingsRepository: SettingsRepository {
    private let store: UserDefaultsStore

    public init(defaults: UserDefaults = .standard) {
        self.store = UserDefaultsStore(defaults: defaults)
    }

    public func load() -> SalaryConfig {
        guard let data = store.data(forKey: UserDefaultsStore.Key.salaryConfig) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(SalaryConfigDTO.self, from: data).toDomain()
        } catch {
            // A corrupt store is indistinguishable from a first launch, and defaults are
            // a better answer than a blank menu bar.
            return .default
        }
    }

    public func save(_ config: SalaryConfig) {
        do {
            let data = try JSONEncoder().encode(SalaryConfigDTO(config))
            store.set(data, forKey: UserDefaultsStore.Key.salaryConfig)
        } catch {
            return
        }
    }
}
