import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryCore
import SalaryPresentation

@main
struct SalaryTickerApp: App {
    @State private var viewModel = TickerViewModel()

    init() {
        // Handles the hidden diagnostic flags and exits; a no-op otherwise.
        DebugCLI.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                if viewModel.config.menuBarShowsProgressRing {
                    MenuBarRingView(percent: MenuBarRingView.percent(of: viewModel.earnings.progress))
                        .equatable()
                }
                // monospacedDigit keeps every glyph the same width — without it the
                // status item visibly twitches as the digits change.
                switch Formatting.menuBarContent(viewModel.earnings, config: viewModel.config) {
                case .text(let value):
                    Text(value).monospacedDigit()
                case .icon:
                    // The ring already stands in for the app; a second glyph beside it
                    // would just take menu bar space to say the same thing twice.
                    if !viewModel.config.menuBarShowsProgressRing {
                        Image(systemName: "banknote")
                    }
                }
            }
            .task { viewModel.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
