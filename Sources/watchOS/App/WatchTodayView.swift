import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryPresentation
import SalaryGlass

/// One number, and only what a raised wrist has time for.
///
/// The phone shows the rates that produce the figure and the month behind it; a watch has
/// room for the figure, how far through the day it is, and — if you scroll — the month and
/// whatever is at the front of the goal queue. Everything past that belongs on a bigger
/// screen, and pretending otherwise just makes the first thing harder to read.
struct WatchTodayView: View {
    @Bindable var viewModel: TickerViewModel

    private var config: SalaryConfig { viewModel.config }
    private var text: Strings { Strings(config.language) }
    private var earnings: Earnings { viewModel.earnings }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if config.isValid {
                    today
                    month
                    if let next = viewModel.pinnedGoals.first { goal(next.goal, next.projection) }
                } else {
                    Text(text.setupNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 4)
        }
        // Restrained deliberately: a watch face is mostly black and mostly glanced at, so
        // the backdrop is a whisper and the glass sits on the one block that matters.
        .background(GlassBackdrop())
        .navigationTitle(text.sectionSalary)
    }

    private var today: some View {
        VStack(spacing: 4) {
            Text(Formatting.money(earnings.todayEarned, config: config))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            Text(Formatting.statusText(earnings.status, text))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ProgressView(value: clamped(earnings.progress))
                .tint(.blue)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .glassPanel(radius: 14)
    }

    private var month: some View {
        HStack {
            Text(text.monthToDate).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(Formatting.money(earnings.monthEarned, symbol: config.currencySymbol,
                                  digits: 2, language: config.language))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func goal(_ goal: SavingsGoal, _ projection: GoalProjection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(goal.name).font(.caption2).lineLimit(1)
                Spacer()
                Text("\(Int((projection.progress * 100).rounded()))%")
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: clamped(projection.progress)).tint(.blue)
        }
    }

    private func clamped(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }
}
