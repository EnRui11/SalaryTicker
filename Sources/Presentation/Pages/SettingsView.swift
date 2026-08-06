import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryCore
import SalaryPresentation

/// The settings window.
///
/// Tabbed rather than one long form: at nine sections the single-column version grew
/// taller than the screen, and because a `Settings` scene sizes itself to its content the
/// bottom simply fell off the display with no way to scroll to it. Each tab now holds a
/// couple of related sections, and the fixed window height means a long translation
/// scrolls inside its tab instead of pushing rows out of reach.
struct SettingsView: View {
    @Bindable var viewModel: TickerViewModel

    /// Pins the visible tab. Only the shot renderer sets it; the app leaves it nil so the
    /// remembered tab wins.
    var pinnedTab: Tab?

    @AppStorage("settingsTab") private var storedTab: String = Tab.salary.rawValue
    @State private var showingZonePicker = false
    @State private var zoneQuery = ""
    @State private var needsApproval = false
    @State private var launchError: String?

    private var config: SalaryConfig { viewModel.config }
    private var text: Strings { Strings(config.language) }

    enum Tab: String, Hashable, CaseIterable {
        case salary, schedule, goals, general
    }

    /// Which tab is showing. Persisted through `@AppStorage` rather than the settings
    /// repository: it is window state, the same kind of thing macOS already remembers
    /// about the window's position, not something the user configured.
    private var selection: Binding<Tab> {
        Binding(
            get: { pinnedTab ?? Tab(rawValue: storedTab) ?? .salary },
            set: { storedTab = $0.rawValue }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            salaryTab
                .tabItem { Label(text.sectionSalary, systemImage: "banknote") }
                .tag(Tab.salary)
            scheduleTab
                .tabItem { Label(text.sectionSchedule, systemImage: "clock") }
                .tag(Tab.schedule)
            goalsTab
                .tabItem { Label(text.sectionGoals, systemImage: "target") }
                .tag(Tab.goals)
            generalTab
                .tabItem { Label(text.sectionGeneral, systemImage: "gearshape") }
                .tag(Tab.general)
        }
        // Sized to the tallest tab (Salary, once the month grid is in it). A shorter window
        // would leave its last rows below the fold on first open, which is the exact problem
        // tabs were meant to fix.
        .frame(width: 500, height: 660)
        // Also drives DatePicker, so the clock reads in the chosen language's convention.
        .environment(\.locale, Locale(identifier: config.language.localeIdentifier))
        .onChange(of: viewModel.config) { viewModel.configChanged() }
        .onAppear { NSApp.activate() }
    }

    // MARK: Tabs

    private var salaryTab: some View {
        Form {
            Section(text.sectionSalary) {
                LabeledContent(text.monthlySalary) {
                    TextField(text.monthlySalary, value: $viewModel.config.monthlySalary,
                              format: .number.precision(.fractionLength(0...2)))
                        .multilineTextAlignment(.trailing)
                        .labelsHidden()
                        .frame(width: 120)
                }
                if config.isValid {
                    // Both follow the month the grid is showing, so paging to September
                    // answers "what will a day be worth then" instead of repeating August.
                    LabeledContent(text.workdaysThisMonth) {
                        Text(text.days(viewModel.monthOverview.workdayCount))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent(text.derivedHourly) {
                        Text(Formatting.money(viewModel.displayedHourlyPay,
                                              symbol: config.currencySymbol, digits: 2, language: config.language))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label(text.invalidNotice, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                Text(text.salaryCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(text.sectionWorkdays) {
                weekdayPicker
                MonthCalendarView(
                    overview: viewModel.monthOverview,
                    text: text,
                    monthTitle: Formatting.monthTitle(
                        viewModel.displayedMonthDate,
                        language: config.language,
                        timeZone: config.calendar().timeZone
                    ),
                    isCurrentMonth: viewModel.isShowingCurrentMonth,
                    onToggleDay: { viewModel.cycleDayOverride($0) },
                    onStepMonth: { viewModel.stepMonth(by: $0) },
                    onShowCurrentMonth: { viewModel.showCurrentMonth() }
                )
                Text("\(text.weekdayHint)\n\(text.calendarHint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var scheduleTab: some View {
        Form {
            Section(text.sectionSchedule) {
                DatePicker(text.clockIn, selection: time(\.workStart), displayedComponents: .hourAndMinute)
                DatePicker(text.clockOff, selection: time(\.workEnd), displayedComponents: .hourAndMinute)
                Toggle(text.unpaidLunch, isOn: $viewModel.config.lunchEnabled)
                if config.lunchEnabled {
                    DatePicker(text.lunchStart, selection: time(\.lunchStart), displayedComponents: .hourAndMinute)
                    DatePicker(text.lunchEnd, selection: time(\.lunchEnd), displayedComponents: .hourAndMinute)
                }
                LabeledContent(text.paidPerDay) {
                    Text(Formatting.duration(config.dailyPaidSeconds, text))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(text.overnightCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(text.sectionOvertime) {
                Toggle(text.overtimeEnabled, isOn: $viewModel.config.overtimeEnabled)
                if config.overtimeEnabled {
                    LabeledContent(text.overtimeRate) {
                        TextField(text.overtimeRate, value: $viewModel.config.overtimeMultiplier,
                                  format: .number.precision(.fractionLength(0...2)))
                            .multilineTextAlignment(.trailing)
                            .labelsHidden()
                            .frame(width: 70)
                    }
                    LabeledContent(text.overtimeMax) {
                        HStack(spacing: 8) {
                            Text(text.hours(config.overtimeMaxHours)).monospacedDigit()
                            Stepper("", value: $viewModel.config.overtimeMaxHours, in: 1...12)
                                .labelsHidden()
                        }
                    }
                    Text(text.overtimeCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var goalsTab: some View {
        Form {
            Section(text.sectionGoals) {
                if config.goals.isEmpty {
                    Text(text.noGoalsYet)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach($viewModel.config.goals) { $goal in
                    goalRow($goal)
                }
                Button(text.addGoal, systemImage: "plus") { viewModel.addGoal() }
                Text(text.goalsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func goalRow(_ goal: Binding<SavingsGoal>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // labelsHidden keeps the title inside the field as a placeholder; a Form
                // otherwise promotes it to a row label and strands the field beside it.
                TextField(text.goalNamePlaceholder, text: goal.name)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                TextField(text.goalPrice, value: goal.amount,
                          format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                Button(role: .destructive) {
                    viewModel.removeGoal(goal.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack {
                Toggle(text.showInPanel, isOn: goal.isPinned)
                    .toggleStyle(.checkbox)
                Spacer()
                Text(summary(for: goal.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    /// `1.4 working days · Ready Thu 6 Aug, 14:20`
    private func summary(for goal: SavingsGoal) -> String {
        guard goal.isValid else { return "" }
        let projection = viewModel.projection(for: goal)
        let cost = text.workdaysCost(Formatting.workdays(projection.workdays, language: config.language))
        guard let readyAt = projection.readyAt else { return "\(cost) · \(text.goalOutOfReach)" }
        let stamp = Formatting.readyTimestamp(
            readyAt, language: config.language, timeZone: config.calendar().timeZone
        )
        return "\(cost) · \(text.readyBy(stamp))"
    }

    private var generalTab: some View {
        Form {
            Section(text.sectionDisplay) {
                Picker(text.languageLabel, selection: $viewModel.config.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                LabeledContent(text.currencySymbol) {
                    TextField(text.currencySymbol, text: $viewModel.config.currencySymbol)
                        .multilineTextAlignment(.trailing)
                        .labelsHidden()
                        .frame(width: 60)
                }
                LabeledContent(text.decimals) {
                    HStack(spacing: 8) {
                        Text("\(config.fractionDigits)").monospacedDigit()
                        Stepper("", value: $viewModel.config.fractionDigits, in: 0...6)
                            .labelsHidden()
                    }
                }
                Toggle(text.menuBarShowRing, isOn: $viewModel.config.menuBarShowsProgressRing)
                Toggle(text.menuBarShowSymbol, isOn: $viewModel.config.menuBarShowsCurrencySymbol)
                Toggle(text.menuBarIconWhenIdle, isOn: $viewModel.config.menuBarIconOnlyWhenIdle)
                LabeledContent(text.menuBarPreview) {
                    switch Formatting.menuBarContent(viewModel.earnings, config: config) {
                    case .text(let preview):
                        Text(preview).monospacedDigit().foregroundStyle(.secondary)
                    case .icon:
                        Image(systemName: "banknote").foregroundStyle(.secondary)
                    }
                }
            }

            Section(text.timeZoneLabel) {
                // A plain Picker over ~600 identifiers builds every row up front — tens of
                // megabytes of menu, and unusable to scroll. A search popover renders only
                // what matches.
                LabeledContent {
                    Button(text.changeAction) { showingZonePicker = true }
                        .popover(isPresented: $showingZonePicker, arrowEdge: .bottom) {
                            zonePicker
                        }
                } label: {
                    Text(currentZoneLabel).lineLimit(1).truncationMode(.middle)
                }
                Text(text.timeZoneCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(text.sectionSystem) {
                // Bound to the stored intent, not to SMAppService — see SalaryConfig.
                Toggle(text.launchAtLogin, isOn: $viewModel.config.launchAtLoginEnabled)
                    .disabled(!viewModel.isLaunchAtLoginSupported)
                    .onChange(of: viewModel.config.launchAtLoginEnabled) { _, newValue in
                        switch viewModel.setLaunchAtLogin(newValue) {
                        case .success(let state):
                            needsApproval = state == .requiresApproval
                            launchError = nil
                        case .failure(let error):
                            needsApproval = false
                            launchError = (error as? LoginItemError) != nil
                                ? text.notBundledError
                                : error.localizedDescription
                            viewModel.config.launchAtLoginEnabled = !newValue
                        }
                    }
                if !viewModel.isLaunchAtLoginSupported {
                    Text(text.notBundledCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if needsApproval {
                    Label(text.launchNeedsApproval, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Pieces

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let weight = config.scheduledWeight(forWeekday: weekday)
                Button { cycleWeekday(weekday) } label: {
                    VStack(spacing: 1) {
                        Text(text.weekdayInitials[weekday - 1])
                        if weight == 0.5 {
                            Text("½").font(.caption2)
                        }
                    }
                    .frame(minWidth: 34, minHeight: weight == 0.5 ? 34 : 26)
                }
                .buttonStyle(.borderless)
                .background(weight > 0 ? Color.accentColor.opacity(weight == 0.5 ? 0.55 : 1)
                                       : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(weight > 0 ? Color.white : Color.primary)
                .accessibilityLabel(weekdayLabel(weekday, weight: weight))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// off → full day → half day → off.
    private func cycleWeekday(_ weekday: Int) {
        if !viewModel.config.workdays.contains(weekday) {
            viewModel.config.workdays.insert(weekday)
            viewModel.config.halfDays.remove(weekday)
        } else if !viewModel.config.halfDays.contains(weekday) {
            viewModel.config.halfDays.insert(weekday)
        } else {
            viewModel.config.workdays.remove(weekday)
            viewModel.config.halfDays.remove(weekday)
        }
    }

    private func weekdayLabel(_ weekday: Int, weight: Double) -> String {
        let name = text.weekdayInitials[weekday - 1]
        if weight == 0 { return "\(name), \(text.dayOff)" }
        return weight < 1 ? "\(name), \(text.halfDay)" : name
    }

    private var currentZoneLabel: String {
        guard let identifier = config.timeZoneIdentifier else {
            return "\(text.systemTimeZone) — \(Self.label(for: TimeZone.current.identifier))"
        }
        return Self.label(for: identifier)
    }

    private var matchingZones: [String] {
        let query = zoneQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return Self.zoneIdentifiers }
        return Self.zoneIdentifiers.filter { $0.lowercased().contains(query) }
    }

    private var zonePicker: some View {
        VStack(spacing: 0) {
            TextField(text.searchPlaceholder, text: $zoneQuery)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    zoneRow(label: "\(text.systemTimeZone) — \(Self.label(for: TimeZone.current.identifier))",
                            identifier: nil)
                    Divider()
                    ForEach(matchingZones, id: \.self) { identifier in
                        zoneRow(label: Self.label(for: identifier), identifier: identifier)
                    }
                }
            }
        }
        .frame(width: 340, height: 320)
    }

    private func zoneRow(label: String, identifier: String?) -> some View {
        Button {
            viewModel.config.timeZoneIdentifier = identifier
            showingZonePicker = false
            zoneQuery = ""
        } label: {
            HStack {
                Text(label).lineLimit(1)
                Spacer()
                if config.timeZoneIdentifier == identifier {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    /// Sorted once: `knownTimeZoneIdentifiers` is ~600 entries and re-sorting it on every
    /// keystroke would be wasteful.
    private static let zoneIdentifiers: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()

    /// `Asia/Kuala_Lumpur (UTC+8)` — the offset is what people actually recognise.
    private static func label(for identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let minutes = zone.secondsFromGMT() / 60
        let sign = minutes < 0 ? "-" : "+"
        let hours = abs(minutes) / 60
        let remainder = abs(minutes) % 60
        let offset = remainder == 0
            ? "UTC\(sign)\(hours)"
            : String(format: "UTC%@%d:%02d", sign, hours, remainder)
        return "\(identifier) (\(offset))"
    }

    /// `DatePicker` speaks `Date`; the config stores wall-clock hour/minute.
    private func time(_ keyPath: WritableKeyPath<SalaryConfig, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { viewModel.config[keyPath: keyPath].asPickerDate() },
            set: { viewModel.config[keyPath: keyPath] = TimeOfDay(from: $0) }
        )
    }
}
