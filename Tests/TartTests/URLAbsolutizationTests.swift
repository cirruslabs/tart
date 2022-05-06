import XCTest
@testable import tart

final class URLAbsolutizationTets: XCTestCase {
  func testNeedsAbsolutization() throws {
    let url = URL(string: "/v2/some/path?some=query")!
            .absolutize(URL(string: "https://example.com/v2/")!)

    XCTAssertEqual(url.absoluteString, "https://example.com/v2/some/path?some=query")
  }

  func testDoesntNeedAbsolutization() throws {
    let url = URL(string: "https://example.org/v2/some/path?some=query")!
            .absolutize(URL(string: "https://example.com/v2/")!)

    XCTAssertEqual(url.absoluteString, "https://example.org/v2/some/path?some=query")
  }
}
