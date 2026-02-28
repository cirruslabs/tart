import Darwin
import Foundation
import XCTest
@testable import tart

final class NetworkFDTests: XCTestCase {
  func testAcceptsConnectedDatagramSocket() throws {
    let (fdLeft, fdRight) = try makeDatagramSocketPair()
    defer {
      _ = close(fdLeft)
      _ = close(fdRight)
    }

    let network = try NetworkFD(fd: fdLeft)

    XCTAssertEqual(network.attachments().count, 1)
  }

  func testRejectsClosedFileDescriptor() throws {
    let (fdLeft, fdRight) = try makeDatagramSocketPair()
    defer { _ = close(fdRight) }

    _ = close(fdLeft)

    XCTAssertThrowsError(try NetworkFD(fd: fdLeft)) { error in
      self.assertVMConfigurationError(error, contains: "file descriptor is not open")
    }
  }

  func testRejectsNonSocketFileDescriptor() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    XCTAssertTrue(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let fd = open(fileURL.path, O_RDONLY)
    XCTAssertGreaterThanOrEqual(fd, 0)
    defer { _ = close(fd) }

    XCTAssertThrowsError(try NetworkFD(fd: fd)) { error in
      self.assertVMConfigurationError(error, contains: "must reference a socket")
    }
  }

  func testRejectsUnconnectedDatagramSocket() throws {
    let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
    XCTAssertGreaterThanOrEqual(fd, 0)
    defer { _ = close(fd) }

    XCTAssertThrowsError(try NetworkFD(fd: fd)) { error in
      self.assertVMConfigurationError(error, contains: "socket must be connected")
    }
  }

  private func makeDatagramSocketPair() throws -> (Int32, Int32) {
    var fds: [Int32] = [-1, -1]
    let result = socketpair(AF_UNIX, SOCK_DGRAM, 0, &fds)

    if result == -1 {
      throw RuntimeError.VMConfigurationError("failed to create a datagram socketpair for tests")
    }

    return (fds[0], fds[1])
  }

  private func assertVMConfigurationError(
    _ error: Error,
    contains expectedSubstring: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case RuntimeError.VMConfigurationError(let message) = error else {
      XCTFail("Expected RuntimeError.VMConfigurationError, got \(error)", file: file, line: line)
      return
    }

    XCTAssertTrue(
      message.contains(expectedSubstring),
      "Expected message to contain \"\(expectedSubstring)\", got \"\(message)\"",
      file: file,
      line: line
    )
  }
}
