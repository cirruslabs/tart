import Foundation
import Virtualization

class IPSWCache: PrunableStorage {
  let baseURL: URL

  init() throws {
    baseURL = try Config().tartCacheDir.appendingPathComponent("IPSWs", isDirectory: true)
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  func locationFor(image: VZMacOSRestoreImage) -> URL {
    baseURL.appendingPathComponent("\(image.buildVersion).ipsw", isDirectory: false)
  }

  func prunables() throws -> [Prunable] {
    try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".ipsw")}
  }
}
