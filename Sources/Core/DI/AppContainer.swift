import Foundation
import SalaryDomain
import SalaryApplication
import SalaryData

/// Composition root: the one place that knows which concrete implementation backs each
/// contract. Everything else receives what it needs through its initialiser.
public struct AppContainer: Sendable {
    public let loadSettings: LoadSettingsUseCase
    public let saveSettings: SaveSettingsUseCase
    public let calculateEarnings: CalculateEarningsUseCase
    public let setLaunchAtLogin: SetLaunchAtLoginUseCase
    /// Carries a configuration to another machine, and reads one that arrives.
    public let configLink: any ConfigLinkCoding

    public init(
        settings: any SettingsRepository = UserDefaultsSettingsRepository(),
        loginItem: any LoginItemService = SMAppServiceLoginItem(),
        calendar: Calendar = .current
    ) {
        loadSettings = LoadSettingsUseCase(repository: settings)
        saveSettings = SaveSettingsUseCase(repository: settings)
        calculateEarnings = CalculateEarningsUseCase(calendar: calendar)
        setLaunchAtLogin = SetLaunchAtLoginUseCase(service: loginItem)
        configLink = ConfigLinkCoder()
    }

    /// Container backed by an isolated defaults suite, for previews and shots.
    public static func preview(suiteName: String) -> AppContainer {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppContainer(settings: UserDefaultsSettingsRepository(defaults: defaults))
    }
}
