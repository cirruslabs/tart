import XCTest
@testable import tart

final class RunNetworkValidationTests: XCTestCase {
  func testNetFdRejectsNegativeValue() throws {
    XCTAssertThrowsError(try Run.parseAsRoot(["unused", "--net-fd=-1"])) { error in
      self.assertError(error, contains: "--net-fd must be greater than or equal to 0")
    }
  }

  func testNetFdConflictsWithNetBridged() throws {
    XCTAssertThrowsError(try Run.parseAsRoot(["unused", "--net-fd", "3", "--net-bridged=en0"])) { error in
      self.assertError(error, contains: "--net-bridged, --net-softnet, --net-host and --net-fd are mutually exclusive")
    }
  }

  func testNetFdConflictsWithNetSoftnet() throws {
    XCTAssertThrowsError(try Run.parseAsRoot(["unused", "--net-fd", "3", "--net-softnet"])) { error in
      self.assertError(error, contains: "--net-bridged, --net-softnet, --net-host and --net-fd are mutually exclusive")
    }
  }

  func testNetFdConflictsWithNetHost() throws {
    XCTAssertThrowsError(try Run.parseAsRoot(["unused", "--net-fd", "3", "--net-host"])) { error in
      self.assertError(error, contains: "--net-bridged, --net-softnet, --net-host and --net-fd are mutually exclusive")
    }
  }

  private func assertError(
    _ error: Error,
    contains expectedSubstring: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      String(describing: error).contains(expectedSubstring),
      "Expected error to contain \"\(expectedSubstring)\", got \"\(error)\"",
      file: file,
      line: line
    )
  }
}
