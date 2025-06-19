import XCTest
@testable import tart

final class DiskImageFormatTests: XCTestCase {
  func testRawFormatIsAlwaysSupported() throws {
    XCTAssertTrue(DiskImageFormat.raw.isSupported)
  }

  func testASIFFormatSupport() throws {
    // ASIF should be supported on macOS 15+
    if #available(macOS 15, *) {
      XCTAssertTrue(DiskImageFormat.asif.isSupported)
    } else {
      XCTAssertFalse(DiskImageFormat.asif.isSupported)
    }
  }

  func testFormatFromString() throws {
    XCTAssertEqual(DiskImageFormat(rawValue: "raw"), .raw)
    XCTAssertEqual(DiskImageFormat(rawValue: "asif"), .asif)
    XCTAssertNil(DiskImageFormat(rawValue: "invalid"))
  }

  func testCaseInsensitivity() throws {
    XCTAssertEqual(DiskImageFormat(argument: "ASIF"), .asif) // case insensitive
    XCTAssertEqual(DiskImageFormat(argument: "Raw"), .raw)  // case insensitive
  }

  func testAllValueStrings() throws {
    let allValues = DiskImageFormat.allValueStrings
    XCTAssertTrue(allValues.contains("raw"))
    XCTAssertTrue(allValues.contains("asif"))
    XCTAssertEqual(allValues.count, 2)
  }

  func testVMConfigDiskFormatSerialization() throws {
    // Test that VMConfig properly serializes and deserializes disk format
    let config = VMConfig(
      platform: Linux(),
      cpuCountMin: 2,
      memorySizeMin: 1024 * 1024 * 1024,
      diskFormat: .asif
    )

    XCTAssertEqual(config.diskFormat, .asif)

    // Test JSON encoding/decoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)

    let decoder = JSONDecoder()
    let decodedConfig = try decoder.decode(VMConfig.self, from: data)

    XCTAssertEqual(decodedConfig.diskFormat, .asif)
  }

  func testVMConfigDefaultDiskFormat() throws {
    // Test that VMConfig defaults to raw format
    let config = VMConfig(
      platform: Linux(),
      cpuCountMin: 2,
      memorySizeMin: 1024 * 1024 * 1024
    )

    XCTAssertEqual(config.diskFormat, .raw)
  }
}
