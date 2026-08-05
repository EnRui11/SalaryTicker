import Foundation

/// What the system currently thinks about launching this app at login.
public enum LoginItemState: Equatable, Sendable {
    /// Login items do not exist for this build (not running from a bundle).
    case unsupported
    case notRegistered
    /// Registered, but the user still has to approve it in System Settings.
    case requiresApproval
    case enabled
}

/// Registering the app to start at login.
///
/// An interface here rather than a direct `SMAppService` call in the view keeps the
/// presentation layer free of ServiceManagement, and makes the reconcile logic testable
/// against a fake — which matters, because the real API is not straightforward: macOS
/// registers menu bar apps in Background Task Management merely for running, and
/// `SMAppService.mainApp.status` reports that as `.enabled` even when nothing ever called
/// `register()`. The system's answer alone cannot tell you what the user asked for.
public protocol LoginItemService: Sendable {
    /// False when the app is not running from a bundle, where login items cannot exist.
    var isSupported: Bool { get }
    var state: LoginItemState { get }

    func register() throws
    func unregister() throws
}

public enum LoginItemError: LocalizedError, Equatable {
    case notBundled

    public var errorDescription: String? {
        "Move SalaryTicker.app into /Applications before enabling launch at login."
    }
}
