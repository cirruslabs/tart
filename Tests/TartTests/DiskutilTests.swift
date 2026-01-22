import XCTest
@testable import tart

final class DiskutilTests: XCTestCase {
  func testDiskutilInfo() throws {
    // Create a temporary directory
    let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("tart-diskutil-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: tempDirURL)
    }

    // Create a 123 GB ASIF disk
    let diskURL = tempDirURL.appendingPathComponent("disk.asif")
    try Diskutil.imageCreate(diskURL: diskURL, sizeGB: 123)

    // Retrieve its information and ensure that it does indeed take 123 GB
    let info = try Diskutil.imageInfo(diskURL)
    XCTAssertEqual(123 * 1000 * 1000 * 1000, try info.totalBytes())
  }
}
