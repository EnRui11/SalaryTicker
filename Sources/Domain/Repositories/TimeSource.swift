import Foundation

/// Where "now" comes from.
///
/// The calculators deliberately do not use this — they take `now` as a parameter, which is
/// what makes them testable without any clock at all. The view model is different: it is
/// the piece that decides *when* to ask, and it holds caches keyed on which day it is.
/// Those caches are invisible to any test that cannot move the day underneath a live
/// instance, and a day boundary is not something a test suite can afford to wait for.
public protocol TimeSource: Sendable {
    var now: Date { get }
}

/// This Mac's clock.
public struct SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
}
