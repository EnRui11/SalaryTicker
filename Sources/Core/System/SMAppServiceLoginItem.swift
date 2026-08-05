import Foundation
import ServiceManagement
import SalaryDomain

/// `SMAppService`-backed implementation of the domain's login item contract.
public struct SMAppServiceLoginItem: LoginItemService {

    public init() {}

    /// Login items are keyed off the bundle identifier, so this only works from the built
    /// `.app` — not from a bare `swift run` binary.
    public var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    public var state: LoginItemState {
        guard isSupported else { return .unsupported }
        return switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .notRegistered
        @unknown default: .notRegistered
        }
    }

    public func register() throws {
        guard isSupported else { throw LoginItemError.notBundled }
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        guard isSupported else { throw LoginItemError.notBundled }
        try SMAppService.mainApp.unregister()
    }

    /// Raw status string, for the `--login-status` diagnostic.
    public var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered: "notRegistered"
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        @unknown default: "unknown"
        }
    }
}
