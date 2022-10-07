import Foundation

extension URL: Prunable {
  var url: URL {
    self
  }

  func delete() throws {
    try FileManager.default.removeItem(at: self)
  }

  func sizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
  }
}
