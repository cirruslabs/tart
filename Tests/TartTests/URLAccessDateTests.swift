import XCTest
@testable import tart

final class URLAccessDateTests: XCTestCase {
  func testGetAndSetAccessTime() throws {
    // Create a temporary file
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    var tmpFile = tmpDir.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: tmpFile.path, contents: nil)

    // Ensure it's access date is different than our desired access date
    let arbitraryDate = Date.init(year: 2008, month: 09, day: 28, hour: 23, minute: 15)
    XCTAssertNotEqual(arbitraryDate, try tmpFile.accessDate())

    // Set our desired access date for a file
    try tmpFile.updateAccessDate(arbitraryDate)

    // Ensure the access date has changed to our value
    tmpFile.removeCachedResourceValue(forKey: .contentAccessDateKey)
    XCTAssertEqual(arbitraryDate, try tmpFile.accessDate())
  }
}
