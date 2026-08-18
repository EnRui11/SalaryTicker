import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryGlass

/// Collects a goal before it exists.
///
/// The main screen shows only goals that are `isValid`, so the blank-append the settings
/// list uses would write a goal to disk and then display it nowhere — and a second tap on
/// a button that appeared to do nothing would quietly write another. Asking first is what
/// makes the button honest: nothing is created, saved or sent to the watch until there is
/// something worth creating, and cancelling leaves no trace.
///
/// It hands back two scalars rather than a `SavingsGoal`. That is deliberate and not
/// fussiness: `SavingsGoal.init` defaults `startedAt` to the system clock, so a goal built
/// here would be stamped with wall time and step around the injected `TimeSource` that
/// every projection test depends on. The view model stamps it.
struct GoalComposerSheet: View {
    let text: Strings
    let onAdd: (String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// Optional so the field can be genuinely empty rather than showing a `0` that has to
    /// be cleared before a price can be typed — and that silently makes `8999` into 89,990
    /// if it is not. A price nobody has entered yet is absent, not zero.
    @State private var amount: Double?
    @FocusState private var nameFocused: Bool

    /// Asks the domain what counts as complete instead of restating the rule here, so the
    /// button cannot start disagreeing with `isValid` later.
    private var isComplete: Bool {
        SavingsGoal(name: name, amount: amount ?? 0).isValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Card {
                        LabeledRow(label: text.goalNamePlaceholder) {
                            TextField("", text: $name)
                                .multilineTextAlignment(.trailing)
                                .focused($nameFocused)
                        }
                        RowDivider()
                        LabeledRow(label: text.goalPrice) {
                            TextField(
                                text.goalPrice, value: $amount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 110)
                        }
                    }
                    CardCaption(text: text.goalNeedsDetails)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(GlassBackdrop())
            .scrollContentBackground(.hidden)
            .navigationTitle(text.newGoal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(text.cancelAction) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(text.addGoal) {
                        onAdd(name, amount ?? 0)
                        dismiss()
                    }
                    .bold()
                    .disabled(!isComplete)
                }
            }
            .onAppear { nameFocused = true }
        }
    }
}
