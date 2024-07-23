import Foundation
import XAttr

extension URL: Prunable {
  var url: URL {
    self
  }

  func delete() throws {
    try FileManager.default.removeItem(at: self)
  }

  func allocatedSizeBytes() throws -> Int {
    let values = try resourceValues(forKeys: [.totalFileAllocatedSizeKey, .mayShareFileContentKey])
    // make sure the file's origin file is there and duplication works
    var dedublicatedSize = 0
    if values.mayShareFileContent == true {
      dedublicatedSize = Int(deduplicatedBytes())
    }
    return values.totalFileAllocatedSize! - dedublicatedSize
  }

  func sizeBytes() throws -> Int {
    try resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize!
  }

  func setDeduplicatedBytes(_ size: UInt64) {
    let data = "\(size)".data(using: .utf8)!
    try! self.setExtendedAttribute(name: "run.tart.deduplicated-bytes", value: data)
  }

  func deduplicatedBytes() -> UInt64 {
    guard let data = try? self.extendedAttributeValue(forName: "run.tart.deduplicated-bytes") else {
      return 0
    }
    if let strValue = String(data: data, encoding: .utf8) {
      return UInt64(strValue) ?? 0
    }
    return 0
  }
}
