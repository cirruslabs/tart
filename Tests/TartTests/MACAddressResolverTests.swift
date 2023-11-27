import XCTest
import Network
@testable import tart

final class MACAddressResolverTests: XCTestCase {
  func testSingleEntry() throws {
    let leases = try Leases("""
    {
      ip_address=1.2.3.4
      hw_address=1,00:11:22:33:44:55
      lease=0x7fffffff
    }
    """)

    XCTAssertEqual(IPv4Address("1.2.3.4"),
                   leases.ResolveMACAddress(macAddress: MACAddress(fromString: "00:11:22:33:44:55")!))
  }

  func testMultipleEntries() throws {
    let leases = try Leases("""
    {
      ip_address=1.2.3.4
      hw_address=1,00:11:22:33:44:55
      lease=0x7fffffff
    }
    {
      ip_address=5.6.7.8
      hw_address=1,AA:BB:CC:DD:EE:FF
      lease=0x7fffffff
    }
    """)

    XCTAssertEqual(IPv4Address("1.2.3.4"),
                   leases.ResolveMACAddress(macAddress: MACAddress(fromString: "00:11:22:33:44:55")!))
    XCTAssertEqual(IPv4Address("5.6.7.8"),
                   leases.ResolveMACAddress(macAddress: MACAddress(fromString: "AA:BB:CC:DD:EE:FF")!))
  }
}
