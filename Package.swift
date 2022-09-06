// swift-tools-version:5.7

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
    .package(url: "https://github.com/mhdhejazi/Dynamic", branch: "master"),
    .package(url: "https://github.com/swift-server/async-http-client", from: "1.11.4"),
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/malcommac/SwiftDate", from: "6.3.1"),
    .package(url: "https://github.com/antlr/antlr4", revision: "4.10.1")
  ],
  targets: [
    .executableTarget(name: "tart", dependencies: [
      .product(name: "Algorithms", package: "swift-algorithms"),
      .product(name: "ArgumentParser", package: "swift-argument-parser"),
      .product(name: "AsyncHTTPClient", package: "async-http-client"),
      .product(name: "Dynamic", package: "Dynamic"),
      .product(name: "SwiftDate", package: "SwiftDate"),
      .product(name: "Antlr4", package: "Antlr4"),
    ]),
    .testTarget(name: "TartTests", dependencies: ["tart"])
  ]
)
