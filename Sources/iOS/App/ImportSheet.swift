import SwiftUI
import SalaryDomain
import SalaryShared

/// What arrived, before any of it is applied.
///
/// Importing replaces every setting at once, so the salary and the hours are shown first.
/// Agreeing to a configuration you cannot see is how you end up reading a number built out
/// of somebody else's month.
struct ImportSheet: View {
    let incoming: SalaryConfig
    let onApply: () -> Void
    let onCancel: () -> Void

    private var text: Strings { Strings(incoming.language) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(text.monthlySalary, money(incoming.monthlySalary))
                    if incoming.monthlyAllowance > 0 {
                        row(text.monthlyAllowance, money(incoming.monthlyAllowance))
                    }
                }
                Section {
                    row(text.clockIn, clock(incoming.workStart))
                    row(text.clockOff, clock(incoming.workEnd))
                    row(text.workdaysThisMonth, "\(incoming.workdays.count)")
                    if !incoming.goals.isEmpty {
                        row(text.sectionGoals, "\(incoming.goals.count)")
                    }
                }
                Section {
                    Text(text.importMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(text.importTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(text.cancelAction, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(text.importAction, action: onApply).bold()
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func money(_ amount: Double) -> String {
        Formatting.money(amount, symbol: incoming.currencySymbol, digits: 2, language: incoming.language)
    }

    private func clock(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}
