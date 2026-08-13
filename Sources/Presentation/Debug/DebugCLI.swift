import AppKit
import SalaryCore

/// Hidden diagnostic flags, handled before any UI is created.
///
///     SalaryTicker --login-status          print the login-item registration state
///     SalaryTicker --render-shots <dir>    render every UI state to PNGs
///     SalaryTicker --share-link            print the settings link the QR encodes
///
/// Both are read-only apart from writing the requested PNGs.
@MainActor
enum DebugCLI {

    static func runIfRequested() {
        if CommandLine.arguments.contains("--login-status") {
            let service = SMAppServiceLoginItem()
            let stored = AppContainer().loadSettings().launchAtLoginEnabled
            print("bundle:        \(Bundle.main.bundlePath)")
            print("supported:     \(service.isSupported)")
            print("stored intent: \(stored)")
            print("system state:  \(service.state) (SMAppService: \(service.statusDescription))")
            exit(0)
        }
        if CommandLine.arguments.contains("--share-link") {
            // The same link the QR code draws. Printing it is how the phone's import is
            // tested, since a simulator has no camera to scan with.
            print(AppContainer().configLink.url(for: AppContainer().loadSettings()).absoluteString)
            exit(0)
        }
        PreviewShot.runIfRequested()
    }
}
