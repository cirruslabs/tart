import XCTest
@testable import tart

final class DirectoryShareTests: XCTestCase {
  func testNamedParsing() throws {
    let share = try DirectoryShare(parseFrom: "build:/Users/admin/build")
    XCTAssertEqual(share.name, "build")
    XCTAssertEqual(share.path, URL(filePath: "/Users/admin/build"))
    XCTAssertFalse(share.readOnly)
  }

  func testNamedReadOnlyParsing() throws {
    let share = try DirectoryShare(parseFrom: "build:/Users/admin/build:ro")
    XCTAssertEqual(share.name, "build")
    XCTAssertEqual(share.path, URL(filePath: "/Users/admin/build"))
    XCTAssertTrue(share.readOnly)
  }

  func testOptionalNameParsing() throws {
    let share = try DirectoryShare(parseFrom: "/Users/admin/build")
    XCTAssertNil(share.name)
    XCTAssertEqual(share.path, URL(filePath: "/Users/admin/build"))
    XCTAssertFalse(share.readOnly)
  }

  func testOptionalNameReadOnlyParsing() throws {
    let share = try DirectoryShare(parseFrom: "/Users/admin/build:ro")
    XCTAssertNil(share.name)
    XCTAssertEqual(share.path, URL(filePath: "/Users/admin/build"))
    XCTAssertTrue(share.readOnly)
  }

  func testMountTagParsing() throws {
    let share = try DirectoryShare(parseFrom: "/Users/admin/build:tag=foo-bar")
    XCTAssertNil(share.name)
    XCTAssertEqual(share.path, URL(filePath: "/Users/admin/build"))
    XCTAssertFalse(share.readOnly)
    XCTAssertEqual(share.mountTag, "foo-bar")


    let roShare = try DirectoryShare(parseFrom: "/Users/admin/build:ro,tag=foo-bar")
    XCTAssertNil(roShare.name)
    XCTAssertEqual(roShare.path, URL(filePath: "/Users/admin/build"))
    XCTAssertTrue(roShare.readOnly)
    XCTAssertEqual(roShare.mountTag, "foo-bar")
  }
}
