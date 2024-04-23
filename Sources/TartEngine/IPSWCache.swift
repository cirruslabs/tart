import Foundation
import Virtualization

package class IPSWCache: PrunableStorage {
  let baseURL: URL

  package init(config: any ConfigProtocol) throws {
    baseURL = config.tartCacheIPSWsDir
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  package func locationFor(fileName: String) -> URL {
    baseURL.appendingPathComponent(fileName, isDirectory: false)
  }

  package func prunables() throws -> [Prunable] {
    try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.hasSuffix(".ipsw")}
  }
}
