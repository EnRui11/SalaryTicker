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
    platforms: [.macOS(.v14)],
    targets: [
        // Pure business rules. No dependencies at all — not even on Foundation types
        // that imply storage or UI.
        .target(name: "SalaryDomain", path: "Sources/Domain"),

        // One class per user intent, orchestrating the domain. No UI framework imports.
        .target(name: "SalaryApplication", dependencies: ["SalaryDomain"], path: "Sources/Application"),

        // Repository implementations, DTOs, mappers, local store.
        .target(name: "SalaryData", dependencies: ["SalaryDomain"], path: "Sources/Data"),

        // Domain-neutral reusable pieces: formatting and the string table.
        .target(name: "SalaryShared", dependencies: ["SalaryDomain"], path: "Sources/Shared"),

        // Cross-cutting infrastructure and the composition root.
        .target(
            name: "SalaryCore",
            dependencies: ["SalaryDomain", "SalaryApplication", "SalaryData"],
            path: "Sources/Core"
        ),

        // The app itself: SwiftUI scenes, pages and view state.
        .executableTarget(
            name: "SalaryTicker",
            dependencies: ["SalaryDomain", "SalaryApplication", "SalaryShared", "SalaryCore"],
            path: "Sources/Presentation"
        ),

        .testTarget(name: "DomainTests", dependencies: ["SalaryDomain"], path: "Tests/DomainTests"),
        .testTarget(name: "DataTests", dependencies: ["SalaryData", "SalaryDomain"], path: "Tests/DataTests"),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["SalaryApplication", "SalaryDomain"],
            path: "Tests/ApplicationTests"
        ),
        .testTarget(name: "SharedTests", dependencies: ["SalaryShared", "SalaryDomain"], path: "Tests/SharedTests"),
    ]
)
