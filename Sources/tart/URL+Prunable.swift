import Foundation

extension URL: Prunable {
  var url: URL {
    self
  }

  func delete() throws {
    try FileManager.default.removeItem(at: self)
  }

  func allocatedSizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
  }

  func sizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize!
  }
}
