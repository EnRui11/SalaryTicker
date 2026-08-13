import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryPresentation

/// Everything the Mac can set, on a phone.
///
/// One scrolling column of cards rather than the Mac's tabs: a phone scrolls anyway, and
/// tabs would hide the thing you came to change behind a guess about which tab it lives in.
/// The order follows the questions in the order they get asked — what you are paid, when you
/// work, which days, what you are saving for, and only then how it all looks.
struct MobileSettingsView: View {
    @Bindable var viewModel: TickerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var goalPendingDeletion: SavingsGoal?

    private var config: SalaryConfig { viewModel.config }
    private var text: Strings { Strings(config.language) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    pay
                    hours
                    workdays
                    goals
                    display
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(text.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(text.doneAction) { dismiss() }.bold()
                }
            }
            .onChange(of: viewModel.config) { viewModel.configChanged() }
            .confirmationDialog(
                goalPendingDeletion.map { text.deleteGoalTitle($0.name) } ?? "",
                isPresented: Binding(
                    get: { goalPendingDeletion != nil },
                    set: { if !$0 { goalPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: goalPendingDeletion
            ) { goal in
                Button(text.deleteAction, role: .destructive) { viewModel.removeGoal(goal.id) }
                Button(text.cancelAction, role: .cancel) {}
            } message: { _ in
                Text(text.deleteGoalMessage)
            }
        }
    }

    // MARK: Pay

    private var pay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Card(title: text.sectionSalary) {
                LabeledRow(label: text.monthlySalary) {
                    amountField($viewModel.config.monthlySalary)
                }
                RowDivider()
                LabeledRow(label: text.monthlyAllowance) {
                    amountField($viewModel.config.monthlyAllowance)
                }
                if config.isValid {
                    RowDivider()
                    LabeledRow(text.derivedHourly, money(viewModel.displayedHourlyPay))
                } else {
                    RowDivider()
                    Label(text.invalidNotice, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.vertical, 11)
                }
            }
            CardCaption(text: text.allowanceCaption)
        }
    }

    // MARK: Hours

    private var hours: some View {
        VStack(alignment: .leading, spacing: 8) {
            Card(title: text.sectionSchedule) {
                DatePicker(text.clockIn, selection: time(\.workStart), displayedComponents: .hourAndMinute)
                    .padding(.vertical, 5)
                RowDivider()
                DatePicker(text.clockOff, selection: time(\.workEnd), displayedComponents: .hourAndMinute)
                    .padding(.vertical, 5)
                RowDivider()
                Toggle(text.unpaidLunch, isOn: $viewModel.config.lunchEnabled)
                    .padding(.vertical, 8)
                if config.lunchEnabled {
                    RowDivider()
                    DatePicker(text.lunchStart, selection: time(\.lunchStart), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 5)
                    RowDivider()
                    DatePicker(text.lunchEnd, selection: time(\.lunchEnd), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 5)
                }
                RowDivider()
                LabeledRow(text.paidPerDay, Formatting.duration(config.dailyPaidSeconds, text))
            }
            CardCaption(text: text.overnightCaption)
        }
    }

    // MARK: Working days

    private var workdays: some View {
        VStack(alignment: .leading, spacing: 8) {
            Card(title: text.sectionWorkdays) {
                WeekdayPicker(config: $viewModel.config, text: text)
                    .padding(.vertical, 10)
                RowDivider()
                MonthGridView(
                    overview: viewModel.monthOverview,
                    text: text,
                    title: Formatting.monthTitle(
                        viewModel.displayedMonthDate,
                        language: config.language,
                        timeZone: config.calendar().timeZone
                    ),
                    isCurrentMonth: viewModel.isShowingCurrentMonth,
                    onToggleDay: { viewModel.cycleDayOverride($0) },
                    onStepMonth: { viewModel.stepMonth(by: $0) },
                    onShowCurrentMonth: { viewModel.showCurrentMonth() }
                )
                .padding(.vertical, 10)
            }
            CardCaption(text: "\(text.weekdayHint)\n\(text.calendarHint)")
        }
    }

    // MARK: Goals

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Card(title: text.sectionGoals) {
                if config.goals.isEmpty {
                    EmptyHint(
                        icon: "target",
                        message: text.noGoalsYet,
                        action: (text.addGoal, { viewModel.addGoal() })
                    )
                } else {
                    ForEach(Array($viewModel.config.goals.enumerated()), id: \.element.id) { index, $goal in
                        if index > 0 { RowDivider() }
                        GoalEditorRow(
                            goal: $goal,
                            index: index,
                            total: config.goals.count,
                            projection: viewModel.projection(for: goal),
                            text: text,
                            currencySymbol: config.currencySymbol,
                            onMoveUp: { viewModel.moveGoalUp(goal.id) },
                            onMoveDown: { viewModel.moveGoalDown(goal.id) },
                            onDelete: { goalPendingDeletion = goal }
                        )
                    }
                    RowDivider()
                    Button {
                        viewModel.addGoal()
                    } label: {
                        Label(text.addGoal, systemImage: "plus")
                    }
                    .padding(.vertical, 11)
                }
            }
            CardCaption(text: text.goalsPriorityCaption)
        }
    }

    // MARK: Display

    private var display: some View {
        Card(title: text.sectionDisplay) {
            LabeledRow(label: text.currencySymbol) {
                TextField("", text: $viewModel.config.currencySymbol)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }
            RowDivider()
            LabeledRow(label: text.decimals) {
                Stepper("\(config.fractionDigits)", value: $viewModel.config.fractionDigits, in: 0...6)
                    .fixedSize()
            }
            RowDivider()
            LabeledRow(label: text.languageLabel) {
                Picker("", selection: $viewModel.config.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: Pieces

    private func amountField(_ value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 110)
    }

    private func money(_ amount: Double) -> String {
        Formatting.money(amount, symbol: config.currencySymbol, digits: 2, language: config.language)
    }

    /// `TimeOfDay` is minutes from midnight; `DatePicker` wants a `Date`. Anchored on today
    /// rather than the epoch, because a zone's historical offset can be a fraction of an
    /// hour and would round the picker's answer to something the user did not choose.
    private func time(_ path: WritableKeyPath<SalaryConfig, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { config[keyPath: path].asPickerDate(calendar: config.calendar()) },
            set: { viewModel.config[keyPath: path] = TimeOfDay(from: $0, calendar: config.calendar()) }
        )
    }
}
