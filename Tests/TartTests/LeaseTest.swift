import XCTest
@testable import tart

import Network
import SwiftRadix

final class LeaseTests: XCTestCase {
  func testCorrectTimezone() throws {
    let lease = Lease(fromRawLease: [
      "hw_address": "1,11:22:33:44:55:66",
      "ip_address": "1.2.3.4",
      "lease": "0x6565da9e",
    ])

    XCTAssertNotNil(lease)
    XCTAssertEqual(lease!.expiresAt.toISO(), "2023-11-28T12:18:38Z")
  }
}
