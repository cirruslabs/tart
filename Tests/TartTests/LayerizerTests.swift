import XCTest
@testable import tart

final class LayerizerTests: XCTestCase {
  var registryRunner: RegistryRunner?

  var registry: Registry {
    registryRunner!.registry
  }

  override func setUp() async throws {
    try await super.setUp()

    do {
      registryRunner = try await RegistryRunner()
    } catch {
      try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == nil)
    }
  }

  override func tearDown() async throws {
    try await super.tearDown()

    registryRunner = nil
  }

  func testDiskV1() async throws {
    // Original disk file to be pushed to the registry
    let devUrandom = try FileHandle(forReadingFrom: URL(filePath: "/dev/urandom"))
    defer { try! devUrandom.close() }

    let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil)
    let temporaryFile = try FileHandle(forWritingTo: temporaryFileURL)
    for _ in 0..<5 {
      let randomData = try devUrandom.read(upToCount: 1 * 1024 * 1024 * 1024)!
      try temporaryFile.write(contentsOf: randomData)
    }
    try temporaryFile.close()

    // Disk file to be pulled from the registry
    // and compared against the original disk file
    let canaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    print("pushing disk...")
    let diskLayers = try await DiskV1.push(diskURL: temporaryFileURL, registry: registry, chunkSizeMb: 0, progress: Progress())

    print("pulling disk...")
    try await DiskV1.pull(registry: registry, diskLayers: diskLayers, diskURL: canaryFileURL, concurrency: 16, progress: Progress())

    print("comparing disks...")
    try XCTAssertEqual(Digest.hash(temporaryFileURL), Digest.hash(canaryFileURL))
  }

  func testDiskV2() async throws {
    // Original disk file to be pushed to the registry
    let devUrandom = try FileHandle(forReadingFrom: URL(filePath: "/dev/urandom"))
    defer { try! devUrandom.close() }

    let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil)
    let temporaryFile = try FileHandle(forWritingTo: temporaryFileURL)
    for _ in 0..<5 {
      let randomData = try devUrandom.read(upToCount: 1 * 1024 * 1024 * 1024)!
      try temporaryFile.write(contentsOf: randomData)
    }
    try temporaryFile.close()

    // Disk file to be pulled from the registry
    // and compared against the original disk file
    let canaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    print("pushing disk...")
    let diskLayers = try await DiskV2.push(diskURL: temporaryFileURL, registry: registry, chunkSizeMb: 0, progress: Progress())

    print("pulling disk...")
    try await DiskV2.pull(registry: registry, diskLayers: diskLayers, diskURL: canaryFileURL, concurrency: 16, progress: Progress())

    print("comparing disks...")
    try XCTAssertEqual(Digest.hash(temporaryFileURL), Digest.hash(canaryFileURL))
  }
}
