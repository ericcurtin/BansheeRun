// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BansheeRun",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BansheeRun", targets: ["BansheeRun"])
    ],
    targets: [
        .executableTarget(
            name: "BansheeRun",
            path: "BansheeRun",
            exclude: ["banshee_run.h", "Info.plist", "BansheeRun.entitlements", "BansheeRun-Bridging-Header.h", "Resources"],
            sources: ["BansheeRunApp.swift", "ContentView.swift", "BansheeLib.swift", "LocationManager.swift", "ActivityRepository.swift", "ActivityListView.swift", "BansheeAudioManager.swift"],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header", "BansheeRun/BansheeRun-Bridging-Header.h"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", "../target/release",
                    "-L", "../target/aarch64-apple-darwin/release",
                    "-lbanshee_run"
                ]),
                .linkedFramework("CoreLocation"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
