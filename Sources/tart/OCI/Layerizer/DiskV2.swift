import Foundation
import Compression

class DiskV2: Disk {
  private static let bufferSizeBytes = 4 * 1024 * 1024
  private static let layerLimitBytes = 500 * 1000 * 1000
  private static let holeGranularityBytes = 64 * 1024

  static func push(diskURL: URL, registry: Registry, chunkSizeMb: Int, progress: Progress) async throws -> [OCIManifestLayer] {
    var pushedLayers: [OCIManifestLayer] = []

    // Open the disk file
    var mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])

    // Compress the disk file as multiple individually decompressible streams,
    // each equal ``Self.layerLimitBytes`` bytes or slightly larger due to the
    // internal compressor's buffer
    var offset: UInt64 = 0

    while let (compressedData, uncompressedSize, uncompressedDigest) = try compressNextLayerOfLimitBytesOrMore(mappedDisk: mappedDisk, offset: offset) {
      offset += uncompressedSize

      let layerDigest = try await registry.pushBlob(fromData: compressedData, chunkSizeMb: chunkSizeMb)

      pushedLayers.append(OCIManifestLayer(
        mediaType: diskV2MediaType,
        size: compressedData.count,
        digest: layerDigest,
        uncompressedSize: uncompressedSize,
        uncompressedContentDigest: uncompressedDigest
      ))

      // Update progress using a relative value
      progress.completedUnitCount += Int64(uncompressedSize)
    }

    return pushedLayers
  }

  static func pull(registry: Registry, diskLayers: [OCIManifestLayer], diskURL: URL, concurrency: UInt, progress: Progress) async throws {
    // Support resumable pulls
    let pullResumed = FileManager.default.fileExists(atPath: diskURL.path)

    if !pullResumed && !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
      throw OCIError.FailedToCreateVmFile
    }

    // Calculate the uncompressed disk size
    var uncompressedDiskSize: UInt64 = 0

    for layer in diskLayers {
      guard let uncompressedLayerSize = layer.uncompressedSize() else {
        throw OCIError.LayerIsMissingUncompressedSizeAnnotation
      }

      uncompressedDiskSize += uncompressedLayerSize
    }

    // Truncate the target disk file so that it will be able
    // to accomodate the uncompressed disk size
    let disk = try FileHandle(forWritingTo: diskURL)
    try disk.truncate(atOffset: uncompressedDiskSize)
    try disk.close()

    // Concurrently fetch and decompress layers
    try await withThrowingTaskGroup(of: Void.self) { group in
      var globalDiskWritingOffset: UInt64 = 0

      for (index, diskLayer) in diskLayers.enumerated() {
        // Respect the concurrency limit
        if index >= concurrency {
          try await group.next()
        }

        // Retrieve layer annotations
        guard let uncompressedLayerSize = diskLayer.uncompressedSize() else {
          throw OCIError.LayerIsMissingUncompressedSizeAnnotation
        }
        guard let uncompressedLayerContentDigest = diskLayer.uncompressedContentDigest() else {
          throw OCIError.LayerIsMissingUncompressedDigestAnnotation
        }

        // Capture the current disk writing offset
        let diskWritingOffset = globalDiskWritingOffset

        // Launch a fetching and decompression task
        group.addTask {
          // No need to fetch and decompress anything if we've already done so
          if try pullResumed && Digest.hash(diskURL, offset: diskWritingOffset, size: uncompressedLayerSize) == uncompressedLayerContentDigest {
            // Update the progress
            progress.completedUnitCount += Int64(diskLayer.size)

            return
          }

          // Open the disk file
          let disk = try FileHandle(forWritingTo: diskURL)

          // A zero chunk for faster than byte-by-byte comparisons
          //
          // Assumes that the other Data(...) is equal in size, but it's fine to get a false-negative
          // on the last block since it costs only 64 KiB of excess data per 500 MB layer.
          //
          // Some simple benchmarks ("sync && sudo purge" command was used to negate the disk caching effects):
          // +--------------------------------------+---------------------------------------------------+
          // | Operation                            | time(1) result                                    |
          // +--------------------------------------+---------------------------------------------------+
          // | Data(...) == zeroChunk               | 2.16s user 11.71s system 73% cpu 18.928 total     |
          // | Data(...).contains(where: {$0 != 0}) | 603.68s user 12.97s system 99% cpu 10:22.85 total |
          // +--------------------------------------+---------------------------------------------------+
          let zeroChunk = Data(count: holeGranularityBytes)
          var diskWritingOffset = diskWritingOffset

          // Pull and decompress a single layer into the specific offset on disk
          let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
            guard let data = data else {
              return
            }

            for chunk in data.chunks(ofCount: holeGranularityBytes) {
              // Only write chunks that are not zero
              if chunk != zeroChunk {
                try disk.seek(toOffset: diskWritingOffset)
                disk.write(chunk)
              }

              diskWritingOffset += UInt64(chunk.count)
            }
          }

          try await registry.pullBlob(diskLayer.digest) { data in
            try filter.write(data)

            // Update the progress
            progress.completedUnitCount += Int64(data.count)
          }

          try filter.finalize()

          try disk.close()
        }

        globalDiskWritingOffset += uncompressedLayerSize
      }
    }
  }

  private static func compressNextLayerOfLimitBytesOrMore(mappedDisk: Data, offset: UInt64) throws -> (Data, UInt64, String)? {
    var compressedData = Data()
    var bytesRead: UInt64 = 0
    let digest = Digest()

    // Create a compressing filter that we will terminate upon
    // reaching ``Self.layerLimitBytes`` of compressed data
    let compressingFilter = try InputFilter(.compress, using: .lz4, bufferCapacity: bufferSizeBytes) { (length: Int) -> Data? in
      if compressedData.count >= Self.layerLimitBytes {
        return nil
      }

      let readFromByte = Int(offset + bytesRead)

      let numBytesToRead = min(mappedDisk.count - readFromByte, bufferSizeBytes)
      if numBytesToRead == 0 {
        return nil
      }

      let uncompressedChunk = mappedDisk.subdata(in: readFromByte ..< (readFromByte + numBytesToRead))

      bytesRead += UInt64(uncompressedChunk.count)
      digest.update(uncompressedChunk)

      return uncompressedChunk
    }

    // Retrieve compressed data chunks, but normally no more than ``Self.layerLimitBytes`` bytes
    while let compressedChunk = try compressingFilter.readData(ofLength: Self.bufferSizeBytes) {
      compressedData.append(compressedChunk)
    }

    // Nothing was read this time from the disk,
    // signal that to the consumer
    if bytesRead == 0 {
      return nil
    }

    return (compressedData, bytesRead, digest.finalize())
  }
}
