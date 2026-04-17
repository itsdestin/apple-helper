// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "apple-helper",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "apple-helper", targets: ["AppleHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "AppleHelper",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            linkerSettings: [
                // Embed Info.plist in the binary so CFBundleDisplayName
                // controls the TCC dialog label.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "AppleHelperTests",
            dependencies: ["AppleHelper"]
        ),
    ]
)
