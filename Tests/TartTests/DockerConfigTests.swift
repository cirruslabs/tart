import XCTest
@testable import tart

final class DockerConfigTests: XCTestCase {
  func testHelpers() throws {
    let config = DockerConfig(credHelpers: [
      "(.*).dkr.ecr.(.*).amazonaws.com": "ecr-login",
      "gcr.io": "gcloud"
    ])

    XCTAssertEqual(try config.findCredHelper(host: "gcr.io"), "gcloud")
    XCTAssertEqual(try config.findCredHelper(host: "123.dkr.ecr.eu-west-1.amazonaws.com"), "ecr-login")
    XCTAssertEqual(try config.findCredHelper(host: "456.dkr.ecr.us-east-1.amazonaws.com"), "ecr-login")
    XCTAssertNil(try config.findCredHelper(host: "ghcr.io"))
  }
}
