import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryPresentation
import SalaryGlass

/// The screen you actually look at.
///
/// One number is the hero and everything else is support: the rates that produce it sit in
/// a single dense row rather than three full-width ones, and the month and the goals follow
/// as separate cards. The same four things the menu bar panel shows, in the same order,
/// because someone who uses both should not have to learn the app twice.
struct TodayView: View {
    @Bindable var viewModel: TickerViewModel
    @State private var showingSettings = false

    private var config: SalaryConfig { viewModel.config }
    private var text: Strings { Strings(config.language) }
    private var earnings: Earnings { viewModel.earnings }

    var body: some View {
        NavigationStack {
            ScrollView {
                if config.isValid {
                    VStack(spacing: 18) {
                        hero
                        rates
                        month
                        goals
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                } else {
                    // The one state the app can be in where there is no number to show.
                    // It names the next move rather than reporting the absence.
                    EmptyHint(
                        icon: "banknote",
                        message: text.setupNotice,
                        action: (text.settingsAction, { showingSettings = true })
                    )
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                }
            }
            // Glass needs something behind it; over a flat colour it is just a wrong grey.
            .background(GlassBackdrop())
            .scrollContentBackground(.hidden)
            .navigationTitle(text.sectionSalary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(text.settingsAction)
                }
            }
            .sheet(isPresented: $showingSettings) {
                MobileSettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: The number

    private var hero: some View {
        VStack(spacing: 8) {
            Text(text.earnedToday)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Formatting.money(earnings.todayEarned, config: config))
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())

            Text(Formatting.statusText(earnings.status, text))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ProgressView(value: clamped(earnings.progress))
                .padding(.top, 10)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: What produces it

    /// Three related facts, so one row rather than three. They never change within a day,
    /// which is exactly why they should not each take a line of a phone screen.
    private var rates: some View {
        HStack(spacing: 0) {
            // Four places, matching the menu bar panel and not the configured precision:
            // a per-second rate rounded to two says $0.01 and means nothing.
            rate(text.perSecond, Formatting.money(
                earnings.ratePerSecond, symbol: config.currencySymbol,
                digits: 4, language: config.language
            ))
            RowDivider().frame(width: 1, height: 34)
            rate(text.hourly, money(earnings.hourlyPay))
            RowDivider().frame(width: 1, height: 34)
            rate(text.fullDay, money(earnings.dailyPay))
        }
        .padding(.vertical, 14)
        .glassPanel()
    }

    private func rate(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The month

    private var month: some View {
        Card {
            LabeledRow(label: text.monthToDate) {
                Text(money(earnings.monthEarned))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            RowDivider()
            LabeledRow(
                text.workdaysDone(
                    earnings.workdaysCompletedThisMonth, earnings.workdaysThisMonth
                ),
                earnings.status.isAccruing ? text.plusToday : ""
            )
        }
    }

    // MARK: Goals

    @ViewBuilder private var goals: some View {
        if viewModel.pinnedGoals.isEmpty {
            Card(title: text.sectionGoals) {
                EmptyHint(icon: "target", message: text.noGoalsYet)
            }
        } else {
            Card(title: text.sectionGoals) {
                ForEach(Array(viewModel.pinnedGoals.enumerated()), id: \.element.goal.id) { index, entry in
                    if index > 0 { RowDivider() }
                    goalRow(index: index, entry.goal, entry.projection)
                }
            }
        }
    }

    private func goalRow(index: Int, _ goal: SavingsGoal, _ projection: GoalProjection) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                // Its place in the queue. Goals are funded top down, so the order is a
                // fact about the money and not just about the list.
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                Text(goal.name).lineLimit(1)
                Spacer()
                Text("\(Int((projection.progress * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: clamped(projection.progress))
            Text(caption(for: projection))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(text.queuePosition(index + 1, viewModel.pinnedGoals.count)), \(goal.name)"
        )
    }

    // MARK: Pieces

    private func clamped(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    private func money(_ amount: Double) -> String {
        Formatting.money(amount, symbol: config.currencySymbol, digits: 2, language: config.language)
    }

    private func caption(for projection: GoalProjection) -> String {
        if projection.progress >= 1 { return text.goalReached }
        guard let readyAt = projection.readyAt else { return text.goalOutOfReach }
        return text.readyBy(Formatting.readyTimestamp(
            readyAt, language: config.language, timeZone: config.calendar().timeZone
        ))
    }
}
