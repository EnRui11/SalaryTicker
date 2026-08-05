import Foundation
import Testing
@testable import SalaryApplication
import SalaryDomain

/// Records what the use case asked the system to do.
private final class FakeLoginItem: LoginItemService, @unchecked Sendable {
    var isSupported: Bool
    var state: LoginItemState
    var registerCount = 0
    var unregisterCount = 0
    var registerError: (any Error)?
    /// What the system reports after a successful register — macOS may want approval.
    var stateAfterRegister: LoginItemState = .enabled

    init(isSupported: Bool = true, state: LoginItemState = .notRegistered) {
        self.isSupported = isSupported
        self.state = state
    }

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        state = stateAfterRegister
    }

    func unregister() throws {
        unregisterCount += 1
        state = .notRegistered
    }
}

/// `Result` with an `any Error` failure is not `Equatable`, so unwrap the success side.
private func succeeded(_ result: Result<LoginItemState, any Error>) -> LoginItemState? {
    guard case .success(let state) = result else { return nil }
    return state
}

// MARK: - Applying a change the user made

@Test func turningItOnRegistersAndReportsTheResultingState() {
    let service = FakeLoginItem()
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(succeeded(useCase(true)) == .enabled)
    #expect(service.registerCount == 1)
}

@Test func turningItOffUnregisters() {
    let service = FakeLoginItem(state: .enabled)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(succeeded(useCase(false)) == .notRegistered)
    #expect(service.unregisterCount == 1)
}

@Test func approvalStillPendingIsReportedRatherThanClaimedAsEnabled() {
    let service = FakeLoginItem()
    service.stateAfterRegister = .requiresApproval
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(succeeded(useCase(true)) == .requiresApproval)
}

@Test func aFailedRegistrationSurfacesTheError() {
    struct Boom: Error {}
    let service = FakeLoginItem()
    service.registerError = Boom()
    let useCase = SetLaunchAtLoginUseCase(service: service)

    switch useCase(true) {
    case .success: Issue.record("expected a failure")
    case .failure: break
    }
}

@Test func anUnbundledBuildRefusesInsteadOfPretending() {
    let service = FakeLoginItem(isSupported: false)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    switch useCase(true) {
    case .success: Issue.record("expected a failure")
    case .failure(let error): #expect(error as? LoginItemError == .notBundled)
    }
    #expect(service.registerCount == 0)
}

// MARK: - Reconciling at launch

@Test func launchingWithTheIntentOnRegistersWhenTheSystemHasNotGotIt() {
    let service = FakeLoginItem(state: .notRegistered)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(useCase.reconcile(desired: true) == .enabled)
    #expect(service.registerCount == 1)
}

@Test func launchingWithTheIntentOnDoesNotReRegisterWhenAlreadyEnabled() {
    let service = FakeLoginItem(state: .enabled)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(useCase.reconcile(desired: true) == .enabled)
    #expect(service.registerCount == 0)
}

@Test func launchingWithTheIntentOffNeverTouchesTheSystem() {
    // The reason this exists: macOS lists menu bar apps in Background Task Management
    // just for running, and reports that as `.enabled`. Reconciling "off" against that
    // would silently strip out an entry the user never asked us to remove.
    let service = FakeLoginItem(state: .enabled)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(useCase.reconcile(desired: false) == .enabled)
    #expect(service.registerCount == 0)
    #expect(service.unregisterCount == 0)
}

@Test func reconcilingAnUnbundledBuildDoesNothing() {
    let service = FakeLoginItem(isSupported: false, state: .unsupported)
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(useCase.reconcile(desired: true) == .unsupported)
    #expect(service.registerCount == 0)
}

@Test func aReconcileThatFailsDoesNotCrashAndReportsTheRealState() {
    struct Boom: Error {}
    let service = FakeLoginItem(state: .notRegistered)
    service.registerError = Boom()
    let useCase = SetLaunchAtLoginUseCase(service: service)

    #expect(useCase.reconcile(desired: true) == .notRegistered)
    #expect(service.registerCount == 1)
}
