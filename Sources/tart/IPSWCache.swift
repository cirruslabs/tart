import Foundation
import Virtualization

class IPSWCache: PrunableStorage {
  let baseURL: URL

  init() throws {
    baseURL = Config.processConfig.tartCacheIPSWsDir
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  func locationFor(fileName: String) -> URL {
    baseURL.appendingPathComponent(fileName, isDirectory: false)
  }

  func prunables() throws -> [Prunable] {
    try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.hasSuffix(".ipsw")}
  }
}
