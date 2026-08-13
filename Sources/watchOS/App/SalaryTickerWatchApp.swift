import SwiftUI
import SalaryPresentation
import SalarySync

/// The watch app.
///
/// Same domain, same view model, same arithmetic as the Mac and the phone. What differs is
/// how long anyone looks at it: a wrist is raised for a couple of seconds, so the screen
/// holds one number and the two facts that give it context, and nothing else.
@main
struct SalaryTickerWatchApp: App {
    @State private var viewModel = TickerViewModel()

    var body: some Scene {
        WindowGroup {
            WatchTodayView(viewModel: viewModel)
                .task {
                    viewModel.start()
                    // Settings cannot be typed here and a watch has no camera, so the
                    // phone is the only way they arrive.
                    ConfigBridge.shared.onReceive = { viewModel.apply($0) }
                    ConfigBridge.shared.start()
                }
        }
    }
}
