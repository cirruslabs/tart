import XCTest

@testable import tart

final class VMDisplayConfigTests: XCTestCase {
  // Test that the default VMDisplayConfig has unit set to .points.
  func testDefaultUnitIsPoints() {
    let config = VMDisplayConfig()
    XCTAssertEqual(config.unit, .points)
  }

  // Test that the description property remains unitless, showing only "widthxheight".
  // This ensures the description does not include the unit, regardless of .points or .pixels.
  func testDescriptionRemainsUnitless() {
    let pointsConfig = VMDisplayConfig(width: 1024, height: 768, unit: .points)
    XCTAssertEqual(pointsConfig.description, "1024x768")

    let pixelsConfig = VMDisplayConfig(width: 1024, height: 768, unit: .pixels)
    XCTAssertEqual(pixelsConfig.description, "1024x768")
  }

  // Helper to construct a minimal valid VMConfig for Linux
  private func makeLinuxVMConfig() -> VMConfig {
    var config = VMConfig(
      platform: Linux(),
      cpuCountMin: 2,
      memorySizeMin: 1024 * 1024 * 1024
    )
    // Ensure current values are valid and consistent
    try? config.setCPU(cpuCount: 2)
    try? config.setMemory(memorySize: 1024 * 1024 * 1024)
    return config
  }

  // Test JSON encoding and decoding round-trip for VMConfig with embedded display unit.
  // Uses non-default width and height to ensure Codable path is exercised, not defaults.
  func testJSONRoundTripWithEmbeddedUnit() throws {
    var config = makeLinuxVMConfig()
    config.display.unit = .pixels
    config.display.width = 1337
    config.display.height = 911

    let encoder = JSONEncoder()
    let data = try encoder.encode(config)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(VMConfig.self, from: data)

    XCTAssertEqual(decoded.display.unit, .pixels)
    XCTAssertEqual(decoded.display.width, 1337)
    XCTAssertEqual(decoded.display.height, 911)
  }

  // Test backward compatibility with JSON that omits display.unit entirely.
  // Uses non-default width and height to ensure Codable path is exercised, not defaults.
  func testDecodingOldConfigWithoutDisplayUnitDefaultsToPoints() throws {
    var config = makeLinuxVMConfig()
    config.display = VMDisplayConfig(width: 1600, height: 900, unit: .pixels)

    // Encode a valid config first
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var data = try encoder.encode(config)

    // Decode to a dictionary we can manipulate
    var object = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

    // Remove the embedded unit from display to simulate older config
    if var display = object["display"] as? [String: Any] {
      display.removeValue(forKey: "unit")
      object["display"] = display
    }

    // Re-encode the modified JSON
    data = try JSONSerialization.data(withJSONObject: object, options: [])

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(VMConfig.self, from: data)

    XCTAssertEqual(decoded.display.unit, .points)
    XCTAssertEqual(decoded.display.width, 1600)
    XCTAssertEqual(decoded.display.height, 900)
  }
}
