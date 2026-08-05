import AppKit
import SalaryCore

/// Hidden diagnostic flags, handled before any UI is created.
///
///     SalaryTicker --login-status          print the login-item registration state
///     SalaryTicker --render-shots <dir>    render every UI state to PNGs
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
        PreviewShot.runIfRequested()
    }
}
