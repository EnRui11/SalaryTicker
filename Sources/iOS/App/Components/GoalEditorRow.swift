import SwiftUI
import SalaryDomain
import SalaryShared

/// One goal, editable, with its place in the funding queue.
///
/// The number is not decoration: goals are paid from the top of the list down, so where a
/// goal sits decides which one the next ringgit belongs to. The arrows move it, because a
/// row this full of text fields has almost nowhere left to grab for a drag.
struct GoalEditorRow: View {
    @Binding var goal: SavingsGoal
    let index: Int
    let total: Int
    let projection: GoalProjection
    let text: Strings
    let currencySymbol: String
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                    .accessibilityLabel(text.queuePosition(index + 1, total))

                TextField(text.goalNamePlaceholder, text: $goal.name)
                    .textFieldStyle(.plain)

                TextField(text.goalPrice, value: $goal.amount,
                          format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 84)
            }

            if goal.isValid {
                HStack(spacing: 8) {
                    ProgressView(value: projection.progress.isFinite
                                 ? min(max(projection.progress, 0), 1) : 0)
                    Text("\(Int((projection.progress * 100).rounded()))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(text.goalNeedsDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Toggle(text.showInPanel, isOn: $goal.isPinned)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text(text.showInPanel).font(.caption).foregroundStyle(.secondary)

                Spacer()

                Button(action: onMoveUp) { Image(systemName: "chevron.up") }
                    .disabled(index == 0)
                    .accessibilityLabel(text.moveGoalUp)
                Button(action: onMoveDown) { Image(systemName: "chevron.down") }
                    .disabled(index >= total - 1)
                    .accessibilityLabel(text.moveGoalDown)
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .accessibilityLabel(text.deleteAction)
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
        .padding(.vertical, 12)
    }

    private var summary: String {
        let cost = text.workdaysCost(Formatting.workdays(projection.workdays, language: text.language))
        if projection.progress >= 1 { return "\(cost) · \(text.goalReached)" }
        guard let readyAt = projection.readyAt else { return "\(cost) · \(text.goalOutOfReach)" }
        return "\(cost) · \(text.readyBy(Formatting.readyTimestamp(readyAt, language: text.language)))"
    }
}
