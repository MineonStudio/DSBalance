// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DSBalance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DSBalance", targets: ["DSBalance"])
    ],
    targets: [
        .executableTarget(
            name: "DSBalance",
            path: "Sources/DSBalance"
        )
    ]
)
