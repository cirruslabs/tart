import Foundation

protocol PrunableStorage {
  func prunables() throws -> [Prunable]
}

protocol Prunable {
  var url: URL { get }
  func delete() throws
  func accessDate() throws -> Date
  // size on disk as seen in Finder including empty blocks
  func sizeBytes() throws -> Int
  // actual size on disk without empty blocks
  func allocatedSizeBytes() throws -> Int
}
