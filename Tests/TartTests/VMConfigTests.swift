import XCTest
@testable import tart

final class VMConfigTests: XCTestCase {
  func testVMDisplayConfig() throws {
    // Defaults units (points)
    var vmDisplayConfig = VMDisplayConfig.init(argument: "1234x5678")
    XCTAssertEqual(VMDisplayConfig(width: 1234, height: 5678, unit: nil), vmDisplayConfig)

    // Explicit units (points)
    vmDisplayConfig = VMDisplayConfig.init(argument: "1234x5678pt")
    XCTAssertEqual(VMDisplayConfig(width: 1234, height: 5678, unit: .point), vmDisplayConfig)

    // Explicit units (pixels)
    vmDisplayConfig = VMDisplayConfig.init(argument: "1234x5678px")
    XCTAssertEqual(VMDisplayConfig(width: 1234, height: 5678, unit: .pixel), vmDisplayConfig)
  }
}
