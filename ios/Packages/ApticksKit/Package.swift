// swift-tools-version: 6.2

import PackageDescription

// Apticks for iOS, split into modules the way larger apps are:
//
//   Domain             models and game rules. No UI, no networking.
//   Networking         the APIClient / AccountClient interfaces features depend on.
//   NetworkingLive     the Supabase implementation (only the app links it).
//   NetworkingFakes    an in-memory backend for previews, UI tests and unit tests.
//   DesignSystem       colours, type, components, motion, the SVG renderer.
//   Tiko               the mascot.
//   AppCore            routing, shared app state and dependencies.
//   Companion          Tiko the companion and the first-run tour.
//   *Feature           one module per screen family, each MVVM.
//
// Features never import each other or NetworkingLive; the app target is
// the composition root that wires them together.

// UI modules run on the main actor by default, like a new Xcode app target.
let ui: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let feature: [Target.Dependency] = ["Domain", "Networking", "DesignSystem", "Tiko", "AppCore"]

let package = Package(
    name: "ApticksKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NetworkingLive", targets: ["NetworkingLive"]),
        .library(name: "NetworkingFakes", targets: ["NetworkingFakes"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Tiko", targets: ["Tiko"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "Companion", targets: ["Companion"]),
        .library(name: "HomeFeature", targets: ["HomeFeature"]),
        .library(name: "DuelFeature", targets: ["DuelFeature"]),
        .library(name: "DailyFeature", targets: ["DailyFeature"]),
        .library(name: "LeaderboardFeature", targets: ["LeaderboardFeature"]),
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
        .library(name: "ChallengeFeature", targets: ["ChallengeFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "FeedbackFeature", targets: ["FeedbackFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]),
        .target(name: "Networking", dependencies: ["Domain"], swiftSettings: ui),
        .target(
            name: "NetworkingLive",
            dependencies: ["Domain", "Networking", .product(name: "Supabase", package: "supabase-swift")],
            swiftSettings: ui
        ),
        .target(name: "NetworkingFakes", dependencies: ["Domain", "Networking"], swiftSettings: ui),
        .target(name: "DesignSystem", dependencies: ["Domain"], swiftSettings: ui),
        .target(name: "Tiko", dependencies: ["DesignSystem"], swiftSettings: ui),
        .target(name: "AppCore", dependencies: ["Domain", "Networking", "DesignSystem", "Tiko"], swiftSettings: ui),
        .target(name: "Companion", dependencies: ["DesignSystem", "Tiko", "AppCore"], swiftSettings: ui),
        .target(name: "HomeFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "DuelFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "DailyFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "LeaderboardFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "ProfileFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "ChallengeFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "OnboardingFeature", dependencies: feature, swiftSettings: ui),
        .target(name: "FeedbackFeature", dependencies: feature, swiftSettings: ui),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: ui),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"], swiftSettings: ui),
        .testTarget(name: "DuelFeatureTests", dependencies: ["DuelFeature", "NetworkingFakes", "AppCore", "Domain"], swiftSettings: ui),
        .testTarget(name: "FeedbackFeatureTests", dependencies: ["FeedbackFeature", "NetworkingFakes", "AppCore", "Domain"], swiftSettings: ui),
        .testTarget(name: "OnboardingFeatureTests", dependencies: ["OnboardingFeature", "NetworkingFakes", "AppCore", "Domain"], swiftSettings: ui),
        .testTarget(name: "HomeFeatureTests", dependencies: ["HomeFeature", "NetworkingFakes", "AppCore", "Domain", "Tiko"], swiftSettings: ui),
        .testTarget(name: "LiveDuelTests", dependencies: ["ChallengeFeature", "DuelFeature", "ProfileFeature", "NetworkingFakes", "Networking", "AppCore", "Domain"], swiftSettings: ui),
    ]
)
