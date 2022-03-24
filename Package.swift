// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "Tart",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.1"),
  ],
  targets: [
    .executableTarget(name: "tart",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
  ]
)
