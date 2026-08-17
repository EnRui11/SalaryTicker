import ActivityKit
import SwiftUI
import WidgetKit
import SalaryActivity

/// The Dynamic Island and the lock screen.
///
/// Everything that moves here moves without this code running. `Text(timerInterval:)` and
/// `ProgressView(timerInterval:)` are animated by the system across a date range, so the
/// countdown to clock-off and the day's progress are live and exact even hours after the
/// app was last open.
///
/// The money is not, and is not pretended to be. Updating it needs the app in the
/// foreground or a push server, and this has neither, so it is shown as a figure with a
/// time attached rather than as a number implying it is still counting. A ticker that has
/// quietly stopped is worse than one that says when it stopped.
struct SalaryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalaryActivityAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(money(state)).font(.title3.weight(.semibold)).monospacedDigit()
                        Text(state.asOf, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.isRunning {
                        // Counts down by itself. No update, no server.
                        Text(timerInterval: state.animatableRange, countsDown: true)
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                    } else {
                        Text(state.shiftStart, style: .time)
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: state.animatableRange, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.green)
                }
            } compactLeading: {
                Image(systemName: state.isRunning ? "banknote" : "moon.zzz")
                    .foregroundStyle(.green)
            } compactTrailing: {
                if state.isRunning {
                    ProgressView(timerInterval: state.animatableRange, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(.green)
                } else {
                    Text(state.shiftStart, style: .time).monospacedDigit()
                }
            } minimal: {
                Image(systemName: "banknote").foregroundStyle(.green)
            }
        }
    }

    private func lockScreen(_ state: SalaryActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(money(state))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Spacer()
                if state.isRunning {
                    Text(timerInterval: state.animatableRange, countsDown: true)
                        .font(.title3)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                } else {
                    Text(state.shiftStart, style: .time).font(.title3).monospacedDigit()
                }
            }
            ProgressView(timerInterval: state.animatableRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.green)

            // Said plainly rather than implied. The figure above stopped moving when the
            // app did, and a reader deserves to know which.
            Text(state.asOf, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func money(_ state: SalaryActivityAttributes.ContentState) -> String {
        let places = min(max(state.fractionDigits, 0), 6)
        let number = state.earned.formatted(.number.precision(.fractionLength(places)))
        return state.currencySymbol + number
    }
}

@main
struct SalaryWidgets: WidgetBundle {
    var body: some Widget { SalaryLiveActivity() }
}
