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
    /// Whether iOS is allowing this app to show Live Activities at all.
    ///
    /// The system's answer, not the user's setting in this app. The two are ANDed: the
    /// in-app switch can only ever subtract, and there is no arrangement of it that shows
    /// an activity iOS has said no to.
    public static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Brings what is on the Dynamic Island into line with what the settings say.
    ///
    /// The only entry point, and deliberately the only one. An earlier shape had a
    /// `refresh` that started or updated and a `stop` that ended, and a setting to choose
    /// between them would have been a race with a one-second fuse: `refresh` is driven by
    /// the money changing, so switching the activity off would have ended it and then let
    /// the next tick request a brand new one — an island that blinks out and comes back
    /// while the user is still looking at the switch they just turned off.
    ///
    /// Every reason not to show one funnels into the same branch, which also makes this
    /// idempotent and therefore safe to call on a timer, on launch, and on every edit.
    @MainActor
    public static func reconcile(config: SalaryConfig, earnings: Earnings, now: Date = Date()) {
        guard isSupported, config.liveActivityEnabled, config.isValid,
              let window = ShiftWindow.current(
                  config: config, at: now, calendar: config.calendar()
              )
        else { return stop() }

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

        showing = true
        enqueue {
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

    /// Ends every activity this app has running.
    ///
    /// Nothing is held between calls. The running activity is looked up from ActivityKit
    /// each time rather than stored, which is both the only way to touch a type that is not
    /// Sendable without sending it, and the more correct of the two: an activity started
    /// before the app was last killed is still out there, and a stored reference would have
    /// died with the process while the thing on the screen did not. That is also what lets
    /// a launch-time reconcile clear an island left over from a previous run.
    @MainActor
    public static func stop() {
        // `showing` and not just an emptiness check: a start may be sitting in the queue
        // and not yet have produced anything to find. Asking ActivityKit at this instant
        // would answer "nothing running", skip the stop, and let the queued start put an
        // island up that no switch is now asking for. The array is still consulted, for the
        // orphan case — an activity left behind by a previous launch, which this process
        // never started and so has no `showing` memory of.
        guard showing || !Activity<SalaryActivityAttributes>.activities.isEmpty else { return }
        showing = false
        enqueue {
            for running in Activity<SalaryActivityAttributes>.activities {
                await running.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// What this process last asked for, as opposed to what ActivityKit has caught up with.
    @MainActor private static var showing = false

    /// The tail of the queue every ActivityKit call is chained onto.
    @MainActor private static var pending: Task<Void, Never>?

    /// Runs the ActivityKit calls one after another, in the order they were asked for.
    ///
    /// Not for thread safety — this is all MainActor — but for ORDER. Requesting an
    /// activity is asynchronous, so a stop arriving a moment after a start would otherwise
    /// enumerate the activities before the start had created one, find nothing to end, and
    /// leave an island up with the switch off and nothing left to trigger another stop.
    /// Chaining each body onto the last means a stop always sees what the start it followed
    /// produced.
    @MainActor
    private static func enqueue(_ work: @MainActor @escaping () async -> Void) {
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            await work()
        }
    }

    #else
    public static var isSupported: Bool { false }
    @MainActor
    public static func reconcile(config: SalaryConfig, earnings: Earnings, now: Date = Date()) {}
    @MainActor
    public static func stop() {}
    #endif
}
