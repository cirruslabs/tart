import XCTest
@testable import tart

final class SetDisplayUnitsTests: XCTestCase {

    // Verify that the CLI parsing accepts singular and plural forms, case-insensitively
    func testResolutionUnitExpressibleByArgumentParsing() {
        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "point"), .points)
        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "points"), .points)
        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "POINTS"), .points)

        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "pixel"), .pixels)
        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "pixels"), .pixels)
        XCTAssertEqual(VMDisplayConfig.ResolutionUnit(argument: "PIXELS"), .pixels)

        XCTAssertNil(VMDisplayConfig.ResolutionUnit(argument: "pt"))
        XCTAssertNil(VMDisplayConfig.ResolutionUnit(argument: "px"))
        XCTAssertNil(VMDisplayConfig.ResolutionUnit(argument: "invalid"))
    }

    // Ensure that when we set the unit and encode VMConfig, both the embedded display.unit and
    // the top-level displayUnit (compat) are correctly persisted with non-default values.
    func testEncodingPersistsDisplayUnitAndTopLevelCompat() throws {
        var config = VMConfig(platform: Linux(), cpuCountMin: 2, memorySizeMin: 1024 * 1024 * 1024)
        // Use non-default values to ensure we don't rely on defaults
        config.display.width = 1600
        config.display.height = 900
        config.display.unit = .pixels

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        // Decode and verify embedded unit and dimensions
        let decoded = try JSONDecoder().decode(VMConfig.self, from: data)
        XCTAssertEqual(decoded.display.unit, .pixels)
        XCTAssertEqual(decoded.display.width, 1600)
        XCTAssertEqual(decoded.display.height, 900)

        // Verify top-level key exists and matches
        let object = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        XCTAssertEqual(object["displayUnit"] as? String, "pixels")
    }
}
