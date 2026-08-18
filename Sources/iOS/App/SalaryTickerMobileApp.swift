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
                    // On launch as well as on every tick, because the tick is driven by the
                    // money changing and the money does not change on a Saturday. Without
                    // this, opening the app on a day off left the island dead until Monday
                    // -- and an island left running by the previous launch was never
                    // cleared, whatever the settings had since been changed to.
                    reconcileLiveActivity()
                }
                // The only moment iOS lets the figure be refreshed is while the app is in
                // front, so it is refreshed on every tick it is in front for and left
                // stamped with the time it stopped.
                .onChange(of: viewModel.earnings.todayEarned) { reconcileLiveActivity() }
                .onChange(of: viewModel.config) { _, latest in
                    // The watch only ever wants the newest settings, so every edit is sent
                    // and each one replaces the last rather than queueing behind it.
                    ConfigBridge.shared.send(latest)
                    // And the island is brought into line in the same breath, which is what
                    // makes switching it off take effect while the user is still looking at
                    // the switch rather than at the next change of the figure.
                    reconcileLiveActivity()
                }
                // The Mac draws a QR code; scanning it opens this. The same link works if
                // it arrives any other way, which is what makes the import testable at all
                // — a simulator has no camera, but it does have `simctl openurl`.
                .onOpenURL { url in
                    // The Dynamic Island points at its own link, which carries nothing --
                    // it only means "show me the number". Letting it fall through would
                    // read it as a settings link, fail, and greet a tap on the island with
                    // an alert saying the link is unreadable. TodayView closes whatever is
                    // open on top of it; there is nothing to do here but stand aside.
                    guard url.host != SalaryActivityLink.host else { return }
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

    private func reconcileLiveActivity() {
        LiveActivityController.reconcile(config: viewModel.config, earnings: viewModel.earnings)
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
