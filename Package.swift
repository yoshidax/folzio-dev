// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "my_img_viewer",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MediaViewerCore", targets: ["MediaViewerCore"]),
        .executable(name: "MediaViewerApp", targets: ["MediaViewerApp"]),
        .executable(name: "make-fixtures", targets: ["make-fixtures"]),
        .executable(name: "make-icon", targets: ["make-icon"]),
    ],
    targets: [
        .target(name: "MediaViewerCore"),
        .executableTarget(
            name: "MediaViewerApp",
            dependencies: ["MediaViewerCore"]
        ),
        .target(
            name: "FixtureKit",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "make-fixtures",
            dependencies: ["FixtureKit"]
        ),
        .executableTarget(name: "make-icon"),
        .testTarget(
            name: "MediaViewerCoreTests",
            dependencies: ["MediaViewerCore", "FixtureKit"]
        ),
        .testTarget(
            name: "MediaViewerPerformanceTests",
            dependencies: ["MediaViewerCore", "FixtureKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
