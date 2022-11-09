import Foundation
import AsyncAlgorithms

class Fetcher {
  func fetch(_ request: URLRequest, viaFile: Bool = false) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    if viaFile {
      return try await fetchViaFile(request)
    }

    return try await fetchViaMemory(request)
  }

  private func fetchViaMemory(_ request: URLRequest) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    let dataCh = AsyncThrowingChannel<Data, Error>()

    let (data, response) = try await URLSession.shared.data(for: request)

    Task {
      await dataCh.send(data)

      dataCh.finish()
    }

    return (dataCh, response as! HTTPURLResponse)
  }

  private func fetchViaFile(_ request: URLRequest) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    let dataCh = AsyncThrowingChannel<Data, Error>()

    let (fileURL, response) = try await URLSession.shared.download(for: request)

    // Acquire a handle to the downloaded file and then remove it.
    //
    // This keeps a working reference to that file, yet we don't
    // have to deal with the cleanup any more.
    let fh = try FileHandle(forReadingFrom: fileURL)
    try FileManager.default.removeItem(at: fileURL)

    Task {
      while let data = try fh.read(upToCount: 64 * 1024 * 1024) {
        await dataCh.send(data)
      }

      dataCh.finish()
    }

    return (dataCh, response as! HTTPURLResponse)
  }
}
