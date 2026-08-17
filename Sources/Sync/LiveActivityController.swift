import Foundation
import SalaryActivity
import SalaryApplication
import SalaryDomain
#if os(iOS)
import ActivityKit
#endif

/// Starts, refreshes and ends the Live Activity.
///
/// Thin for the same reason the watch bridge is: ActivityKit cannot be exercised in a unit
/// test, so the decision it depends on — which stretch of time the system should animate —
/// lives in `ShiftWindow`, which can be. This only assembles a snapshot and hands it over.
///
/// It refreshes whenever the app is in front, which is the only moment iOS will let it. The
/// figure it leaves behind is stamped with the time it was taken, so a glance at a stale
/// number can tell that it is stale.
public enum LiveActivityController {

    #if os(iOS)
    public static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts one if there is none, refreshes it if there is.
    ///
    /// Nothing is held between calls. The running activity is looked up from ActivityKit
    /// each time rather than stored, which is both the only way to touch a type that is not
    /// Sendable without sending it, and the more correct of the two: an activity started
    /// before the app was last killed is still out there, and a stored reference would have
    /// died with the process while the thing on the screen did not.
    @MainActor
    public static func refresh(config: SalaryConfig, earnings: Earnings, now: Date = Date()) {
        guard isSupported, config.isValid else { return }
        guard let window = ShiftWindow.current(
            config: config, at: now, calendar: config.calendar()
        ) else { return }

        let state = SalaryActivityAttributes.ContentState(
            shiftStart: window.start,
            shiftEnd: window.end,
            isRunning: window.isRunning,
            earned: earnings.todayEarned,
            asOf: now,
            currencySymbol: config.currencySymbol,
            fractionDigits: config.fractionDigits
        )
        let staleDate = window.end

        Task {
            // Built here, inside the task, because ActivityContent is not Sendable either.
            // Only the state and the date cross, and both are values.
            let content = ActivityContent(state: state, staleDate: staleDate)
            if let running = Activity<SalaryActivityAttributes>.activities.first {
                await running.update(content)
            } else {
                _ = try? Activity.request(
                    attributes: SalaryActivityAttributes(),
                    content: content,
                    pushType: nil
                )
            }
        }
    }

    public static func stop() {
        Task {
            for running in Activity<SalaryActivityAttributes>.activities {
                await running.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #else
    public static var isSupported: Bool { false }
    @MainActor
    public static func refresh(config: SalaryConfig, earnings: Earnings, now: Date = Date()) {}
    public static func stop() {}
    #endif
}
