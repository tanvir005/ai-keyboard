// swift-tools-version: 5.9
import PackageDescription

// NibKit is shared by both the host app and the keyboard extension.
//
// Deliberately contains no *unguarded* UIKit. Everything here is Foundation and
// SwiftUI only, except the colour tokens, which need UIKit to resolve against the
// current appearance and are behind `#if canImport(UIKit)`. The pure-logic pieces
// (TextContextResolver above all) stay exercisable with `swift test` on any
// machine — no simulator, no Xcode. Keep it that way.
let package = Package(
    name: "NibKit",
    platforms: [
        .iOS(.v17),
        // macOS support exists solely so `swift test` runs headlessly.
        // v14 because the Observation framework (@Observable) requires it.
        .macOS(.v14),
    ],
    products: [
        .library(name: "NibKit", targets: ["NibKit"])
    ],
    targets: [
        .target(name: "NibKit"),
        .testTarget(name: "NibKitTests", dependencies: ["NibKit"]),
    ]
)
