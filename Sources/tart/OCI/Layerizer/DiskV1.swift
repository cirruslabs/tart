import Foundation
import Compression

class DiskV1: Disk {
  private static let bufferSizeBytes = 4 * 1024 * 1024
  private static let layerLimitBytes = 500 * 1000 * 1000

  static func push(diskURL: URL, registry: Registry, chunkSizeMb: Int, progress: Progress) async throws -> [OCIManifestLayer] {
    var pushedLayers: [OCIManifestLayer] = []

    // Open the disk file
    let mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])
    var mappedDiskReadOffset = 0

    // Compress the disk file as a single stream
    let compressingFilter = try InputFilter(.compress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { (length: Int) -> Data? in
      // Determine the size of the next chunk
      let bytesRead = min(length, mappedDisk.count - mappedDiskReadOffset)

      // Read the next uncompressed chunk
      let data = mappedDisk.subdata(in: mappedDiskReadOffset ..< mappedDiskReadOffset + bytesRead)

      // Advance the offset
      mappedDiskReadOffset += bytesRead

      // Provide the uncompressed chunk to the compressing filter
      return data
    }

    // Cut the compressed stream into layers, each equal exactly ``Self.layerLimitBytes`` bytes,
    // except for the last one, which may be smaller
    while let compressedData = try compressingFilter.readData(ofLength: Self.layerLimitBytes) {
      let layerDigest = try await registry.pushBlob(fromData: compressedData, chunkSizeMb: chunkSizeMb)

      pushedLayers.append(OCIManifestLayer(
        mediaType: diskV1MediaType,
        size: compressedData.count,
        digest: layerDigest
      ))

      // Update progress using an absolute value
      progress.completedUnitCount = Int64(mappedDiskReadOffset)
    }

    return pushedLayers
  }

  static func pull(registry: Registry, diskLayers: [OCIManifestLayer], diskURL: URL, concurrency: UInt, progress: Progress) async throws {
    if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }

    // Open the disk file
    let disk = try FileHandle(forWritingTo: diskURL)
    defer { try! disk.close() }

    // Decompress the layers onto the disk in a single stream
    let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
      if let data = data {
        disk.write(data)
      }
    }

    for diskLayer in diskLayers {
      try await registry.pullBlob(diskLayer.digest) { data in
        try filter.write(data)

        // Update the progress
        progress.completedUnitCount += Int64(data.count)
      }
    }

    try filter.finalize()
  }
}
