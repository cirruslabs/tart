import Foundation
import Compression
import System

class DiskV2: Disk {
  private static let bufferSizeBytes = 4 * 1024 * 1024
  private static let layerLimitBytes = 512 * 1024 * 1024

  static func push(diskURL: URL, registry: Registry, chunkSizeMb: Int, progress: Progress) async throws -> [OCIManifestLayer] {
    var pushedLayers: [OCIManifestLayer] = []

    // Open the disk file
    let mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])

    // Compress the disk file as multiple individually decompressible streams,
    // each equal ``Self.layerLimitBytes`` bytes or less due to LZ4 compression
    for data in mappedDisk.chunks(ofCount: layerLimitBytes) {
      let compressedData = try (data as NSData).compressed(using: .lz4) as Data

      let layerDigest = try await registry.pushBlob(fromData: compressedData, chunkSizeMb: chunkSizeMb)

      pushedLayers.append(OCIManifestLayer(
        mediaType: diskV2MediaType,
        size: compressedData.count,
        digest: layerDigest,
        uncompressedSize: UInt64(data.count),
        uncompressedContentDigest: Digest.hash(data)
      ))

      // Update progress using a relative value
      progress.completedUnitCount += Int64(data.count)
    }

    return pushedLayers
  }

  static func pull(registry: Registry, diskLayers: [OCIManifestLayer], diskURL: URL, concurrency: UInt, progress: Progress, localLayerCache: LocalLayerCache? = nil) async throws {
    // Support resumable pulls
    let pullResumed = FileManager.default.fileExists(atPath: diskURL.path)

    if !pullResumed {
      if let localLayerCache = localLayerCache {
        // Clone the local layer cache's disk and use it as a base, potentially
        // reducing the space usage since some blocks won't be written at all
        try FileManager.default.copyItem(at: localLayerCache.diskURL, to: diskURL)
      } else {
        // Otherwise create an empty disk
        if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
          throw OCIError.FailedToCreateVmFile
        }
      }
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

    // Determine the file system block size
    var st = stat()
    if stat(diskURL.path, &st) == -1 {
      let details = Errno(rawValue: errno)

      throw RuntimeError.PullFailed("failed to stat(2) disk \(diskURL.path): \(details)")
    }
    let fsBlockSize = UInt64(st.st_blksize)

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

          // Open the disk file for writing
          let disk = try FileHandle(forWritingTo: diskURL)

          // Also open the disk file for reading and verifying
          // its contents in case the local layer cache is used
          let rdisk: FileHandle? = if localLayerCache != nil {
            try FileHandle(forReadingFrom: diskURL)
          } else {
            nil
          }

          // Check if we already have this layer contents in the local layer cache
          if let localLayerCache = localLayerCache, let data = localLayerCache.find(diskLayer.digest), Digest.hash(data) == uncompressedLayerContentDigest {
            // Fulfil the layer contents from the local blob cache
            _ = try zeroSkippingWrite(disk, rdisk, fsBlockSize, diskWritingOffset, data)
            try disk.close()

            // Update the progress
            progress.completedUnitCount += Int64(diskLayer.size)

            return
          }

          var diskWritingOffset = diskWritingOffset

          // Pull and decompress a single layer into the specific offset on disk
          let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
            guard let data = data else {
              return
            }

            diskWritingOffset = try zeroSkippingWrite(disk, rdisk, fsBlockSize, diskWritingOffset, data)
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

  private static func zeroSkippingWrite(_ disk: FileHandle, _ rdisk: FileHandle?, _ fsBlockSize: UInt64, _ offset: UInt64, _ data: Data) throws -> UInt64 {
    let holeGranularityBytes = 64 * 1024

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

    var offset = offset

    for chunk in data.chunks(ofCount: holeGranularityBytes) {
      // If the local layer cache is used, only write chunks that differ
      // since the base disk can contain anything at any position
      if let rdisk = rdisk {
        // F_PUNCHHOLE requires the holes to be aligned to file system block boundaries
        let isHoleAligned = (offset % fsBlockSize) == 0 && (UInt64(chunk.count) % fsBlockSize) == 0

        if isHoleAligned && chunk == zeroChunk {
          var arg = fpunchhole_t(fp_flags: 0, reserved: 0, fp_offset: off_t(offset), fp_length: off_t(chunk.count))

          if fcntl(disk.fileDescriptor, F_PUNCHHOLE, &arg) == -1 {
            let details = Errno(rawValue: errno)

            throw RuntimeError.PullFailed("failed to punch hole: \(details)")
          }
        } else {
          try rdisk.seek(toOffset: offset)
          let actualContentsOnDisk = try rdisk.read(upToCount: chunk.count)

          if chunk != actualContentsOnDisk {
            try disk.seek(toOffset: offset)
            disk.write(chunk)
          }
        }

        offset += UInt64(chunk.count)

        continue
      }

      // Otherwise, only write chunks that are not zero
      // since the base disk is created from scratch and
      // is zeroed via truncate(2)
      if chunk != zeroChunk {
        try disk.seek(toOffset: offset)
        disk.write(chunk)
      }

      offset += UInt64(chunk.count)
    }

    return offset
  }
}
