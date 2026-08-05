import Foundation
import SalaryDomain

/// One intent: "what has been earned as of this instant".
///
/// Thin by design — the arithmetic belongs to the domain service. Its job is to be the
/// single entry point the presentation layer calls, and to resolve which calendar the
/// schedule is read in: the config's chosen time zone if it has one, otherwise the
/// injected base (this Mac's clock in production, a fixed one in tests).
public struct CalculateEarningsUseCase: Sendable {
    private let baseCalendar: Calendar

    public init(calendar: Calendar = .current) {
        self.baseCalendar = calendar
    }

    public func callAsFunction(
        config: SalaryConfig,
        at now: Date,
        monthTotals: SalaryConfig.MonthTotals? = nil
    ) -> Earnings {
        EarningsCalculator.earnings(
            config: config,
            at: now,
            monthTotals: monthTotals,
            calendar: config.calendar(basedOn: baseCalendar)
        )
    }
}
