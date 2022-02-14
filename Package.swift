// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Tart",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(
      name: "swift-argument-parser",
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMinor(from: "1.0.3")
    ),
  ],
  targets: [
    .executableTarget(name: "Tart",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
  ]
)
