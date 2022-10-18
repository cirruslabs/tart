import Foundation

class URLFetcher {
  static public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, response as! HTTPURLResponse)
  }

  static public func download(for request: URLRequest, into: URL) async throws -> HTTPURLResponse {
    let (location, response) = try await URLSession.shared.download(for: request)
    // URLSession can't download into a location so let's move it right after the download is done
    // Chances of cancellation and the location being not removed is negligibale.
    _ = try! FileManager.default.replaceItemAt(into, withItemAt: location)
    return response as! HTTPURLResponse
  }
}
