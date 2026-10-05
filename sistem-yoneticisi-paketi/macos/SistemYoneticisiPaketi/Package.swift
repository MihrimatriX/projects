// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SistemYoneticisiPaketi",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SistemYoneticisiPaketi", targets: ["SistemYoneticisiPaketi"])
    ],
    targets: [
        .target(
            name: "SistemYoneticisiPaketiLib",
            path: "Sources/SistemYoneticisiPaketi",
            exclude: ["SistemYoneticisiPaketiApp.swift"]
        ),
        .executableTarget(
            name: "SistemYoneticisiPaketi",
            dependencies: ["SistemYoneticisiPaketiLib"],
            path: "Sources/SistemYoneticisiPaketi",
            sources: ["SistemYoneticisiPaketiApp.swift"]
        ),
        .testTarget(
            name: "SistemYoneticisiPaketiTests",
            dependencies: ["SistemYoneticisiPaketiLib"],
            path: "Tests/SistemYoneticisiPaketiTests"
        )
    ]
)
