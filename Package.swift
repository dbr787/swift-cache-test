// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "swift-cache-test",
    platforms: [
        .macOS(.v10_15)  // Specify macOS 10.15 as the minimum version
    ],
    dependencies: [
        // Joke-fetching dependencies
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),

        // Additional dependencies for larger project
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.30.0")
    ],
    targets: [
        .executableTarget(
            name: "swift-cache-test",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "AnyCodable",
                "RxSwift",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ]
)
