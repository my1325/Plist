// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Plist",
    platforms: [.iOS(.v11)],
    products: [
        .library(name: "Plist", targets: ["Plist", "DataWriter"]),
        .library(name: "PlistHandyJSONSupport", targets: ["PlistHandyJSONSupport"])
    ],
    dependencies: [
        .package(url: "https://github.com/alibaba/HandyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/my1325/FilePath.git", branch: "main")
    ],
    targets: [
        .target(name: "DataWriter", dependencies: ["FilePath"]),
        .target(name: "Plist", dependencies: ["FilePath", "DataWriter"]),
        .target(name: "PlistHandyJSONSupport", dependencies: [
            "Plist",
            .product(name: "HandyJSON", package: "HandyJSON")
        ])
    ]
)
