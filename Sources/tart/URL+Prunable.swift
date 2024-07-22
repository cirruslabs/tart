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
    var intVal = size
    let data = Data(bytes: &intVal, count: MemoryLayout.size(ofValue: intVal))
    try! self.setExtendedAttribute(name: "user.deduplicatedBytes", value: data)
  }

  func deduplicatedBytes() -> UInt64 {
    let data = try? self.extendedAttributeValue(forName: "user.deduplicatedBytes")
    if data == nil {
      return 0
    }
    return data!.withUnsafeBytes { $0.load(as: UInt64.self) }
  }
}
