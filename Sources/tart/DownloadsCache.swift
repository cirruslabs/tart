import Foundation
import Virtualization

class DownloadsCache: PrunableStorage {
  let baseURL: URL

  init() throws {
    baseURL = try Config().tartCacheDir.appendingPathComponent("downloads", isDirectory: true)
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  func locationFor(fileName: String) -> URL {
    baseURL.appendingPathComponent(fileName, isDirectory: false)
  }

  func prunables() throws -> [Prunable] {
    try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
  }

  // fetches remote file and caches it by `etag` header
  func retrieveFile(remoteURL: URL) async throws -> URL {
    let fileExtension = remoteURL.pathExtension
    // Check if we already have this file in cache
    var headRequest = URLRequest(url: remoteURL)
    headRequest.httpMethod = "HEAD"
    let (_, headResponse) = try await Fetcher.fetch(headRequest, viaFile: false)

    if let etag = headResponse.value(forHTTPHeaderField: "etag") {
      let expectedLocation = locationFor(fileName: "etag:\(etag).\(fileExtension)")

      if FileManager.default.fileExists(atPath: expectedLocation.path) {
        defaultLogger.appendNewLine("Using cached file for \(remoteURL)...")
        try expectedLocation.updateAccessDate()

        return expectedLocation
      }
    }

    defaultLogger.appendNewLine("Fetching \(remoteURL.lastPathComponent)...")

    let (channel, response) = try await Fetcher.fetch(URLRequest(url: remoteURL), viaFile: true)

    let progress = Progress(totalUnitCount: response.expectedContentLength)
    ProgressObserver(progress).log(defaultLogger)

    let temporaryLocation = try Config().tartTmpDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
    FileManager.default.createFile(atPath: temporaryLocation.path, contents: nil)
    let lock = try FileLock(lockURL: temporaryLocation)
    try lock.lock()

    let fileHandle = try FileHandle(forWritingTo: temporaryLocation)

    for try await chunk in channel {
      let chunkAsData = Data(chunk)
      fileHandle.write(chunkAsData)
      progress.completedUnitCount += Int64(chunk.count)
    }

    try fileHandle.close()

    if let etag = response.value(forHTTPHeaderField: "etag") {
      let finalLocation = locationFor(fileName: "etag:\(etag).\(fileExtension)")
      return try FileManager.default.replaceItemAt(finalLocation, withItemAt: temporaryLocation)!
    }

    defaultLogger.appendNewLine("Was not able to cache \(remoteURL.lastPathComponent) because response lacks Etag header!")
    return temporaryLocation
  }
}
