// swift-tools-version: 6.0
import PackageDescription

// Feature-first Clean Architecture. Each layer is its own target, so the dependency
// direction is enforced by the compiler rather than by discipline: Domain cannot import
// Data, Application cannot import SwiftUI, and Presentation reaches the outside world
// only through Application.
//
// Module names carry a `Salary` prefix because `Data` and `Core` would shadow Foundation
// types and system modules; the folders keep the plain layer names.
let package = Package(
    name: "SalaryTicker",
    // Domain, Application, Data, Shared and Presentation are Foundation-only and build
    // for all three; only the executable and the login-item adapter are macOS-shaped.
    //
    // The floor is 26 across the board because the UI is built on Liquid Glass, which does
    // not exist below it. That would be a serious narrowing for something with users on
    // older machines; this has one user, whose Mac, phone and watch all run 26, and no way
    // to be distributed anyway. Dropping back is a one-line change if that ever stops
    // being true.
    platforms: [.macOS("26.0"), .iOS("26.0"), .watchOS("26.0")],
    // Exported so an Xcode target can depend on them. The macOS app does not need this --
    // it is inside the package -- but an iOS or watchOS app is a separate project and can
    // only see products.
    products: [
        .library(name: "SalaryDomain", targets: ["SalaryDomain"]),
        .library(name: "SalaryApplication", targets: ["SalaryApplication"]),
        .library(name: "SalaryData", targets: ["SalaryData"]),
        .library(name: "SalaryShared", targets: ["SalaryShared"]),
        .library(name: "SalaryGlass", targets: ["SalaryGlass"]),
        .library(name: "SalarySync", targets: ["SalarySync"]),
        .library(name: "SalaryCore", targets: ["SalaryCore"]),
        .library(name: "SalaryPresentation", targets: ["SalaryPresentation"]),
    ],
    targets: [
        // Pure business rules. No dependencies at all — not even on Foundation types
        // that imply storage or UI.
        .target(name: "SalaryDomain", path: "Sources/Domain"),

        // One class per user intent, orchestrating the domain. No UI framework imports.
        .target(name: "SalaryApplication", dependencies: ["SalaryDomain"], path: "Sources/Application"),

        // Repository implementations, DTOs, mappers, local store.
        .target(name: "SalaryData", dependencies: ["SalaryDomain"], path: "Sources/Data"),

        // The glassmorphism treatment, shared so the three platforms cannot drift into
        // three different ideas of the same look.
        .target(name: "SalaryGlass", path: "Sources/Glass"),

        // Phone-to-watch delivery. Thin on purpose: what travels is built and read by
        // SalaryData, which is testable, and this only hands it to WatchConnectivity.
        .target(name: "SalarySync", dependencies: ["SalaryDomain", "SalaryData"], path: "Sources/Sync"),

        // Domain-neutral reusable pieces: formatting and the string table.
        .target(name: "SalaryShared", dependencies: ["SalaryDomain"], path: "Sources/Shared"),

        // Cross-cutting infrastructure and the composition root.
        .target(
            name: "SalaryCore",
            dependencies: ["SalaryDomain", "SalaryApplication", "SalaryData"],
            path: "Sources/Core"
        ),

        // View state, split out of the executable because an executable target cannot be
        // imported by tests. It is the only part of the presentation layer with state of
        // its own — caches keyed on the current day — and therefore the only part where a
        // test can find something the type checker cannot.
        .target(
            name: "SalaryPresentation",
            dependencies: ["SalaryDomain", "SalaryApplication", "SalaryCore"],
            path: "Sources/Presentation/State"
        ),

        // The app itself: SwiftUI scenes, pages and components.
        .executableTarget(
            name: "SalaryTicker",
            dependencies: [
                "SalaryDomain", "SalaryApplication", "SalaryShared", "SalaryCore", "SalaryPresentation", "SalaryData",
                "SalaryGlass",
            ],
            path: "Sources/Presentation",
            exclude: ["State"]
        ),

        .testTarget(name: "DomainTests", dependencies: ["SalaryDomain"], path: "Tests/DomainTests"),
        .testTarget(name: "DataTests", dependencies: ["SalaryData", "SalaryDomain"], path: "Tests/DataTests"),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["SalaryApplication", "SalaryDomain"],
            path: "Tests/ApplicationTests"
        ),
        .testTarget(name: "SharedTests", dependencies: ["SalaryShared", "SalaryDomain"], path: "Tests/SharedTests"),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["SalaryPresentation", "SalaryDomain", "SalaryCore", "SalaryData"],
            path: "Tests/PresentationTests"
        ),
    ]
)
