import Foundation

protocol Disk {
  static func push(diskURL: URL, registry: Registry, chunkSizeMb: Int, progress: Progress) async throws -> [OCIManifestLayer]
  static func pull(registry: Registry, diskLayers: [OCIManifestLayer], diskURL: URL, concurrency: UInt, progress: Progress) async throws
}
