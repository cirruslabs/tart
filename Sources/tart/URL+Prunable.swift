import Foundation

extension URL: Prunable {
  func delete() throws {
    try FileManager.default.removeItem(at: self)
  }

  func sizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
  }
}
