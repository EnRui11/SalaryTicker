import SwiftUI
import SalaryDomain
import SalaryCore
import SalaryPresentation

/// The phone app.
///
/// It owns no arithmetic. Every number on screen comes from the same `TickerViewModel` and
/// the same domain the menu bar app uses — the port is a new view layer, not a second
/// implementation, and the two can therefore never disagree about what a second is worth.
@main
struct SalaryTickerMobileApp: App {
    @State private var viewModel = TickerViewModel()

    var body: some Scene {
        WindowGroup {
            TodayView(viewModel: viewModel)
                .task { viewModel.start() }
        }
    }
}
