import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryCore

/// The panel that drops down from the status item.
struct MenuPanelView: View {
    @Bindable var viewModel: TickerViewModel

    private var config: SalaryConfig { viewModel.config }
    private var earnings: Earnings { viewModel.earnings }
    private var text: Strings { Strings(config.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if earnings.status == .misconfigured {
                misconfiguredNotice
            } else {
                progress
                details
                monthToDate
                if !viewModel.pinnedGoals.isEmpty { goals }
            }
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 300)
        .environment(\.locale, Locale(identifier: config.language.localeIdentifier))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.earnedToday)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Formatting.money(earnings.todayEarned, config: config))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                // Grouping separators and weak-currency salaries make this string long.
                // Shrinking beats wrapping: a two-line headline breaks the whole panel.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Formatting.statusText(earnings.status, text))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: earnings.progress.isFinite ? min(max(earnings.progress, 0), 1) : 0)
                .progressViewStyle(.linear)
            HStack {
                Text(text.todayProgress)
                Spacer()
                Text("\(Int((earnings.progress * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var details: some View {
        VStack(spacing: 6) {
            row(text.perSecond, Formatting.money(earnings.ratePerSecond, symbol: config.currencySymbol, digits: 4, language: config.language))
            row(text.hourly, Formatting.money(earnings.hourlyPay, symbol: config.currencySymbol, digits: 2, language: config.language))
            row(text.fullDay, Formatting.money(earnings.dailyPay, symbol: config.currencySymbol, digits: 2, language: config.language))
        }
    }

    private var monthToDate: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text(text.monthToDate).foregroundStyle(.secondary)
                Spacer()
                Text(Formatting.money(earnings.monthEarned, symbol: config.currencySymbol,
                                      digits: 2, language: config.language))
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(.body)
            HStack {
                Text(text.workdaysDone(earnings.workdaysCompletedThisMonth, earnings.workdaysThisMonth))
                Spacer()
                // On a day off today contributes nothing, so promising "+ today" would lie.
                if earnings.status != .dayOff {
                    Text(text.plusToday)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            ForEach(viewModel.pinnedGoals, id: \.goal.id) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.goal.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int((entry.projection.progress * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)

                    ProgressView(value: entry.projection.progress)
                        .progressViewStyle(.linear)

                    Text(caption(for: entry.projection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func caption(for projection: GoalProjection) -> String {
        guard let readyAt = projection.readyAt else { return text.goalOutOfReach }
        if projection.progress >= 1 { return text.goalReached }
        return text.readyBy(Formatting.readyTimestamp(readyAt, language: config.language))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Without the priority the value gets squeezed before the label does, and
                // shrinks even when there is plenty of room.
                .layoutPriority(1)
        }
        .font(.body)
    }

    private var misconfiguredNotice: some View {
        Label(text.setupNotice, systemImage: "exclamationmark.triangle")
            .font(.body)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        VStack(spacing: 6) {
            SettingsLink {
                Label(text.settingsAction, systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(text.quitAction, systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .font(.body)
    }
}
