import Foundation
import ZIPFoundation

fileprivate let manifestPath = "manifest.json"

class ArchiveReader: RegistryReader {
  let archive: ZIPFoundation.Archive

  init(_ path: String) throws {
    guard let archive = ZIPFoundation.Archive(url: URL(fileURLWithPath: path), accessMode: .read) else {
      throw RuntimeError.ExportFile("at \(path) cannot be opened for reading")
    }

    self.archive = archive
  }

  func pullOperationName() -> String {
    "importing"
  }

  func pullManifest(reference: String) async throws -> (OCIManifest, Data) {
    let manifestData = try readFile(manifestPath)

    return try (OCIManifest(fromJSON: manifestData), manifestData)
  }

  func pullBlob(_ digest: String, handler: (Data) throws -> ()) async throws {
    let blobData = try readFile(digest)

    try handler(blobData)
  }

  private func readFile(_ path: String) throws -> Data {
    guard let entry = archive[path] else {
      throw RuntimeError.ExportFile("corrupted: failed to find entry \(path) referenced in \(manifestPath)")
    }

    var result = Data()

    _ = try archive.extract(entry) { data in
      result.append(data)
    }

    return result
  }
}

class ArchiveWriter: RegistryWriter {
  let archive: ZIPFoundation.Archive

  init(_ path: String) throws {
    // Imitate O_TRUNC since we can't pass it directly to ZIPFoundation.Archive.init()
    try? FileManager.default.removeItem(atPath: path)

    guard let archive = ZIPFoundation.Archive(url: URL(fileURLWithPath: path), accessMode: .create) else {
      throw RuntimeError.ExportFile("at \(path) cannot be created")
    }

    self.archive = archive
  }

  func pushOperationName() -> String {
    "exporting"
  }

  func pushManifest(reference: String, manifest: OCIManifest) async throws -> String {
    let manifestData = try manifest.toJSON()

    try writeFile(manifestPath, manifestData)

    return Digest.hash(manifestData)
  }

  func pushBlob(fromData: Data, chunkSizeMb: Int) async throws -> String {
    let digest = Digest.hash(fromData)

    try writeFile(digest, fromData)

    return digest
  }

  private func writeFile(_ name: String, _ data: Data) throws {
    try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count)) { (position, bufferSize) in
      let upperBound = min(data.count, Int(position) + bufferSize)
      let range = Range(uncheckedBounds: (lower: Int(position), upper: upperBound))

      return data.subdata(in: range)
    }
  }
}
