import Foundation
import SalaryDomain

/// The settings, packed for WatchConnectivity.
///
/// A watch has no camera, so the QR code is no use to it and the phone hands the
/// configuration over directly. What travels is the same link the QR encodes rather than a
/// dictionary of every field: one wire format means one set of version and tolerance rules,
/// and one place to get them wrong instead of two that drift.
public enum ConfigSync {

    static let linkKey = "salaryticker.config.link"

    public static func payload(for config: SalaryConfig) -> [String: Any] {
        [linkKey: ConfigTransfer.url(for: config).absoluteString]
    }

    /// Nil for anything that is not one of our links. Never a partial configuration: a
    /// watch showing a number built from half of one machine and half of another is worse
    /// than a watch showing the defaults it started with.
    public static func config(from payload: [String: Any]) -> SalaryConfig? {
        guard let text = payload[linkKey] as? String, let url = URL(string: text) else { return nil }
        return ConfigTransfer.config(from: url)
    }
}
