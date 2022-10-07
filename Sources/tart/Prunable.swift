import Foundation

protocol PrunableStorage {
  func prunables() throws -> [Prunable]
}

protocol Prunable {
  var url: URL { get }
  func delete() throws
  func accessDate() throws -> Date
  func sizeBytes() throws -> Int
}
