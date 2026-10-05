// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardGecmisiYoneticisi",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClipboardGecmisiYoneticisi", targets: ["ClipboardGecmisiYoneticisi"])
    ],
    targets: [
        // Tek hedef: App.swift diger dosyalardaki internal tipleri (HistoryViewModel vb.) kullanir;
        // ayri Lib modulune bolmek import + public gerektiriyordu ve derleme kiriliyordu.
        // Testler executable hedefi @testable import ile kullanabilir (Swift 5.5+).
        .executableTarget(
            name: "ClipboardGecmisiYoneticisi",
            path: "Sources/ClipboardGecmisiYoneticisi"
        ),
        .testTarget(
            name: "ClipboardGecmisiYoneticisiTests",
            dependencies: ["ClipboardGecmisiYoneticisi"],
            path: "Tests/ClipboardGecmisiYoneticisiTests"
        )
    ]
)
