import Foundation

extension URL: Prunable {
  package var url: URL {
    self
  }

  package func delete() throws {
    try FileManager.default.removeItem(at: self)
  }

  package func allocatedSizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
  }

  package func sizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize!
  }
}
