import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryCore
import SalaryPresentation
import SalarySync
import SalaryActivity

/// The phone app.
///
/// It owns no arithmetic. Every number on screen comes from the same `TickerViewModel` and
/// the same domain the menu bar app uses — the port is a new view layer, not a second
/// implementation, and the two can therefore never disagree about what a second is worth.
@main
struct SalaryTickerMobileApp: App {
    @State private var viewModel = TickerViewModel()

    /// A configuration that has arrived and is waiting to be looked at.
    @State private var incoming: SalaryConfig?
    @State private var rejectedLink = false

    var body: some Scene {
        WindowGroup {
            TodayView(viewModel: viewModel)
                .task {
                    viewModel.start()
                    ConfigBridge.shared.start()
                    ConfigBridge.shared.send(viewModel.config)
                }
                // The only moment iOS lets the figure be refreshed is while the app is in
                // front, so it is refreshed on every tick it is in front for and left
                // stamped with the time it stopped.
                .onChange(of: viewModel.earnings.todayEarned) {
                    LiveActivityController.refresh(
                        config: viewModel.config, earnings: viewModel.earnings
                    )
                }
                // The watch only ever wants the newest settings, so every edit is sent and
                // each one replaces the last rather than queueing behind it.
                .onChange(of: viewModel.config) { _, latest in
                    ConfigBridge.shared.send(latest)
                }
                // The Mac draws a QR code; scanning it opens this. The same link works if
                // it arrives any other way, which is what makes the import testable at all
                // — a simulator has no camera, but it does have `simctl openurl`.
                .onOpenURL { url in
                    if let config = viewModel.configuration(fromLink: url) {
                        incoming = config
                    } else {
                        rejectedLink = true
                    }
                }
                .sheet(item: $incoming) { config in
                    ImportSheet(
                        incoming: config,
                        onApply: {
                            viewModel.apply(config)
                            incoming = nil
                        },
                        onCancel: { incoming = nil }
                    )
                }
                .alert(
                    Strings(viewModel.config.language).importUnreadable,
                    isPresented: $rejectedLink
                ) {
                    Button(Strings(viewModel.config.language).cancelAction, role: .cancel) {}
                }
        }
    }
}

/// `sheet(item:)` wants an identity to key the presentation on. A configuration has no id
/// of its own — it is a value — so it borrows one from what makes it distinct.
extension SalaryConfig: @retroactive Identifiable {
    public var id: Int {
        var hasher = Hasher()
        hasher.combine(monthlySalary)
        hasher.combine(monthlyAllowance)
        hasher.combine(workStart.minutesFromMidnight)
        hasher.combine(workEnd.minutesFromMidnight)
        hasher.combine(goals.count)
        return hasher.finalize()
    }
}
