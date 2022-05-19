// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "Tart",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "tart", targets: ["tart"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.9.2"),
    .package(url: "https://github.com/mhdhejazi/Dynamic", branch: "master"),
  ],
  targets: [
    .executableTarget(name: "tart", dependencies: [
      .product(name: "ArgumentParser", package: "swift-argument-parser"),
      .product(name: "Dynamic", package: "Dynamic"),
      .product(name: "Parsing", package: "swift-parsing"),
    ]),
    .testTarget(name: "TartTests", dependencies: ["tart"])
  ]
)
