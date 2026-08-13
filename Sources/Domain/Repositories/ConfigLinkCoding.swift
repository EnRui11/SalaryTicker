import Foundation

/// Turning a whole configuration into a link, and back.
///
/// A port rather than a direct call, for the same reason the settings store is one: the
/// view model should not know that the encoding happens to be base64 JSON in a query
/// string, only that a link can carry a configuration between two machines.
public protocol ConfigLinkCoding: Sendable {
    func url(for config: SalaryConfig) -> URL
    /// Nil for anything that is not a configuration link this build understands — a wrong
    /// scheme, a later format version, a mangled payload. Never a partial configuration.
    func config(from url: URL) -> SalaryConfig?
}
