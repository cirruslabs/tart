// swift-tools-version:5.10

import PackageDescription
let package = Package(
  name: "Tart",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "tart", targets: ["tart"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.1"),
    .package(url: "https://github.com/mhdhejazi/Dynamic", branch: "master"),
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
    .package(url: "https://github.com/malcommac/SwiftDate", from: "7.0.0"),
    .package(url: "https://github.com/antlr/antlr4", branch: "dev"),
    .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.53.6"),
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.24.0"),
    .package(url: "https://github.com/cfilipov/TextTable", branch: "master"),
    .package(url: "https://github.com/sersoft-gmbh/swift-sysctl.git", from: "1.8.0"),
    .package(url: "https://github.com/orchetect/SwiftRadix", from: "1.3.1"),
    .package(url: "https://github.com/groue/Semaphore", from: "0.0.8"),
    .package(url: "https://github.com/fumoboy007/swift-retry", from: "0.2.3"),
  ],
  targets: [
    .executableTarget(name: "tart", dependencies: [
      .product(name: "Algorithms", package: "swift-algorithms"),
      .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      .product(name: "ArgumentParser", package: "swift-argument-parser"),
      .product(name: "Dynamic", package: "Dynamic"),
      .product(name: "SwiftDate", package: "SwiftDate"),
      .product(name: "Antlr4Static", package: "Antlr4"),
      .product(name: "Atomics", package: "swift-atomics"),
      .product(name: "Sentry", package: "sentry-cocoa"),
      .product(name: "TextTable", package: "TextTable"),
      .product(name: "Sysctl", package: "swift-sysctl"),
      .product(name: "SwiftRadix", package: "SwiftRadix"),
      .product(name: "Semaphore", package: "Semaphore"),
      .product(name: "DMRetry", package: "swift-retry"),
    ], exclude: [
      "OCI/Reference/Makefile",
      "OCI/Reference/Reference.g4",
      "OCI/Reference/Generated/Reference.interp",
      "OCI/Reference/Generated/Reference.tokens",
      "OCI/Reference/Generated/ReferenceLexer.interp",
      "OCI/Reference/Generated/ReferenceLexer.tokens",
    ]),
    .testTarget(name: "TartTests", dependencies: ["tart"])
  ]
)
