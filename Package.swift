// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VilisWhisp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VilisWhisp",
            path: "Sources/VilisWhisp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
