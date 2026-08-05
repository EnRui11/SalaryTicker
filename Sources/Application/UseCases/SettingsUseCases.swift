import Foundation
import SalaryDomain

/// Reads the stored configuration at launch.
public struct LoadSettingsUseCase: Sendable {
    private let repository: any SettingsRepository

    public init(repository: any SettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> SalaryConfig {
        repository.load()
    }
}

/// Persists a configuration edit.
public struct SaveSettingsUseCase: Sendable {
    private let repository: any SettingsRepository

    public init(repository: any SettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ config: SalaryConfig) {
        repository.save(config)
    }
}

/// Applies the user's launch-at-login intent, and keeps the system honest about it.
///
/// The stored intent — not `SMAppService` — is the source of truth for the toggle. macOS
/// lists menu bar apps in Background Task Management just for running, and reports that
/// as `.enabled`, so trusting the system would show the switch on for an app that will
/// not actually start at login.
public struct SetLaunchAtLoginUseCase: Sendable {
    private let service: any LoginItemService

    public init(service: any LoginItemService) {
        self.service = service
    }

    public var isSupported: Bool { service.isSupported }

    /// What the system reports, which is only meaningful next to the stored intent.
    public var systemState: LoginItemState { service.state }

    /// Applies a change the user just made, reporting where the system landed.
    public func callAsFunction(_ desired: Bool) -> Result<LoginItemState, any Error> {
        guard service.isSupported else { return .failure(LoginItemError.notBundled) }
        do {
            if desired {
                try service.register()
            } else {
                try service.unregister()
            }
            return .success(service.state)
        } catch {
            return .failure(error)
        }
    }

    /// Called at launch to make the system match a stored intent of `true`.
    ///
    /// Deliberately one-directional: it never unregisters. An intent of `false` means the
    /// user never asked for auto-start, which is not the same as asking us to strip out
    /// the background entry macOS made on its own — removing that silently would be a
    /// change to their system nobody requested.
    @discardableResult
    public func reconcile(desired: Bool) -> LoginItemState {
        guard service.isSupported, desired else { return service.state }
        guard service.state != .enabled else { return .enabled }

        try? service.register()
        return service.state
    }
}
