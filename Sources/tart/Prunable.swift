import Foundation

protocol PrunableStorage {
  func prunables() throws -> [Prunable]
}

protocol Prunable {
  func delete() throws
  func accessDate() throws -> Date
  func sizeBytes() throws -> Int
}
