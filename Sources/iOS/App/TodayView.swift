import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryPresentation

/// What the menu bar panel says, laid out for a phone held in one hand.
///
/// The same four blocks in the same order — today, the rates behind it, the month, the
/// goals — because someone who uses both should not have to learn the app twice.
struct TodayView: View {
    @Bindable var viewModel: TickerViewModel

    private var config: SalaryConfig { viewModel.config }
    private var text: Strings { Strings(config.language) }
    private var earnings: Earnings { viewModel.earnings }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    today
                    rates
                    month
                    if !viewModel.pinnedGoals.isEmpty { goals }
                }
                .padding()
            }
            .navigationTitle(text.sectionSalary)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Today

    private var today: some View {
        VStack(spacing: 6) {
            Text(text.earnedToday)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // The one number the app exists for. Scales down rather than wrapping, so a
            // four-figure day and a two-figure morning sit on the same line.
            Text(Formatting.money(earnings.todayEarned, config: config))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())

            Text(Formatting.statusText(earnings.status, text))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ProgressView(value: earnings.progress.isFinite ? min(max(earnings.progress, 0), 1) : 0)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Rates

    private var rates: some View {
        card {
            row(text.perSecond, Formatting.money(earnings.ratePerSecond, config: config))
            Divider()
            row(text.hourly, money(earnings.hourlyPay))
            Divider()
            row(text.fullDay, money(earnings.dailyPay))
        }
    }

    private var month: some View {
        card {
            row(text.monthToDate, money(earnings.monthEarned), prominent: true)
            Divider()
            row(
                text.workdaysDone(
                    earnings.workdaysCompletedThisMonth, earnings.workdaysThisMonth
                ),
                earnings.status.isAccruing ? text.plusToday : ""
            )
        }
    }

    private var goals: some View {
        card {
            ForEach(Array(viewModel.pinnedGoals.enumerated()), id: \.element.goal.id) { index, entry in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.goal.name).lineLimit(1)
                        Spacer()
                        Text("\(Int((entry.projection.progress * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: entry.projection.progress)
                    Text(caption(for: entry.projection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Pieces

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ label: String, _ value: String, prominent: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(prominent ? .primary : .secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(prominent ? .semibold : .regular)
        }
        .font(prominent ? .title3 : .body)
    }

    private func money(_ amount: Double) -> String {
        Formatting.money(amount, symbol: config.currencySymbol, digits: 2, language: config.language)
    }

    private func caption(for projection: GoalProjection) -> String {
        guard let readyAt = projection.readyAt else { return text.goalOutOfReach }
        if projection.progress >= 1 { return text.goalReached }
        return text.readyBy(Formatting.readyTimestamp(
            readyAt, language: config.language, timeZone: config.calendar().timeZone
        ))
    }
}
