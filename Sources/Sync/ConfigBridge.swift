import Foundation
import SalaryData
import SalaryDomain
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Carries the settings from the phone to the watch.
///
/// Deliberately thin. `WCSession` cannot be stood up in a unit test, so every decision this
/// touches lives somewhere that can be: what travels is built and read by `ConfigSync`,
/// which has tests, and this type only hands it to the system and hands back what arrives.
/// The rule is that a bug here should be a bug about delivery, never about meaning.
///
/// `updateApplicationContext` rather than a message or a file transfer: the watch only ever
/// wants the newest settings, and that is exactly what an application context is — one
/// dictionary, replaced rather than queued, delivered when the system next gets a chance.
/// A missed update is not a lost update; the next one supersedes it.
@MainActor
public final class ConfigBridge: NSObject {

    /// Called on the watch when settings arrive.
    public var onReceive: ((SalaryConfig) -> Void)?

    public static let shared = ConfigBridge()

    /// The newest settings, kept so they can be sent once there is a session to send them
    /// on. `activate()` completes asynchronously, so anything handed over before the
    /// callback arrives would otherwise be dropped on the floor — which is exactly what
    /// happened the first time this ran: the phone sent on launch, activation had not
    /// finished, and the watch sat on its defaults looking like a delivery problem.
    private var latest: SalaryConfig?

    private override init() { super.init() }

    public func start() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        // Anything that arrived while this side was not running is waiting in the context.
        if let waiting = ConfigSync.config(from: session.receivedApplicationContext) {
            deliver(waiting)
        }
        #endif
    }

    /// Sends the current settings, replacing anything already queued.
    ///
    /// Silently does nothing when there is no counterpart, which is the ordinary state of
    /// a phone with no watch rather than an error worth telling anyone about.
    public func send(_ config: SalaryConfig) {
        latest = config
        flush()
    }

    /// Hands the newest settings over if there is anywhere to hand them.
    ///
    /// Attempted rather than pre-checked. `isPaired` and `isWatchAppInstalled` are the
    /// obvious guards and they are unreliable in a simulator, so the send is simply tried
    /// and allowed to fail: with no counterpart there is nothing to report anyway, and the
    /// next activation tries again with the same value.
    private func flush() {
        #if canImport(WatchConnectivity)
        guard let config = latest, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext(ConfigSync.payload(for: config))
        #endif
    }

    private func deliver(_ config: SalaryConfig) {
        onReceive?(config)
    }
}

#if canImport(WatchConnectivity)
extension ConfigBridge: WCSessionDelegate {

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: (any Error)?
    ) {
        // Decoded here rather than carried across: a [String: Any] is not Sendable, and a
        // SalaryConfig is. Handing the value over instead of the dictionary is what makes
        // this safe rather than merely quiet.
        let waiting = ConfigSync.config(from: session.receivedApplicationContext)
        Task { @MainActor in
            // Both directions on the one callback: send whatever was queued before the
            // session was ready, and take anything that arrived while this side was not.
            self.flush()
            if let waiting { self.deliver(waiting) }
        }
    }

    nonisolated public func session(
        _ session: WCSession, didReceiveApplicationContext context: [String: Any]
    ) {
        guard let config = ConfigSync.config(from: context) else { return }
        Task { @MainActor in self.deliver(config) }
    }

    #if os(iOS)
    // Required on iOS so the session can be handed to a different watch. Nothing here owns
    // per-watch state, so reactivating is all there is to do.
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}
#endif
