import Foundation
import AsyncAlgorithms

fileprivate func getURLSession() -> URLSession {
  let config = URLSessionConfiguration.default

  // Harbor expects a CSRF token to be present if the HTTP client
  // carries a session cookie between its requests[1] and fails if
  // it was not present[2].
  //
  // To fix that, we disable the automatic cookies carry in URLSession.
  //
  // [1]: https://github.com/goharbor/harbor/blob/a4c577f9ec4f18396207a5e686433a6ba203d4ef/src/server/middleware/csrf/csrf.go#L78
  // [2]: https://github.com/cirruslabs/tart/issues/295
  config.httpShouldSetCookies = false

  return URLSession(configuration: config)
}

fileprivate let urlSession = getURLSession()

class Fetcher {
  static func fetch(_ request: URLRequest, viaFile: Bool = false) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    if viaFile {
      return try await fetchViaFile(request)
    }

    return try await fetchViaMemory(request)
  }

  private static func fetchViaMemory(_ request: URLRequest) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    let dataCh = AsyncThrowingChannel<Data, Error>()

    let (data, response) = try await URLSession.shared.data(for: request)

    Task {
      await dataCh.send(data)

      dataCh.finish()
    }

    return (dataCh, response as! HTTPURLResponse)
  }

  private static func fetchViaFile(_ request: URLRequest) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
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
