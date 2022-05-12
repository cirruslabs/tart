import XCTest
@testable import tart

final class TokenResponseTests: XCTestCase {
  func testBasic() throws {
    let tokenResponseRaw = Data("{\"token\":\"some token\"}".utf8)
    let tokenResponse = try TokenResponse.parse(fromData: tokenResponseRaw)

    XCTAssertEqual(tokenResponse.token, "some token")

    let expectedTokenExpiresAtRange = Date()...Date().addingTimeInterval(60)
    XCTAssertTrue(expectedTokenExpiresAtRange.contains(tokenResponse.tokenExpiresAt))

    XCTAssertTrue(tokenResponse.isValid)
  }

  func testExpirationBasic() throws {
    let tokenResponseRaw = Data("{\"token\":\"some token\",\"expires_in\":2}".utf8)
    let tokenResponse = try TokenResponse.parse(fromData: tokenResponseRaw)

    XCTAssertEqual(tokenResponse.expiresIn, 2)

    let expectedTokenExpiresAtRange = Date()...Date().addingTimeInterval(2)
    XCTAssertTrue(expectedTokenExpiresAtRange.contains(tokenResponse.tokenExpiresAt))

    XCTAssertTrue(tokenResponse.isValid)
    _ = XCTWaiter.wait(for: [expectation(description: "Wait 3 seconds for the token to become invalid")], timeout: 2)
    XCTAssertFalse(tokenResponse.isValid)
  }

  func testExpirationWithIssuedAt() throws {
    let tokenResponseRaw = Data("{\"token\":\"some token\",\"expires_in\":3600,\"issued_at\":\"1970-01-01T00:00:00Z\"}".utf8)
    let tokenResponse = try TokenResponse.parse(fromData: tokenResponseRaw)

    XCTAssertEqual(Date(timeIntervalSince1970: 3600), tokenResponse.tokenExpiresAt)
    XCTAssertFalse(tokenResponse.isValid)
  }
}
