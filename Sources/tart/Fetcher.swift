import Foundation

fileprivate var urlSessionConfiguration: URLSessionConfiguration {
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

  return config
}

class Fetcher {
  static func fetch(_ request: URLRequest, viaFile: Bool = false, progress: Progress? = nil) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
    let delegate = Delegate()
    let session = URLSession(configuration: urlSessionConfiguration, delegate: delegate, delegateQueue: nil)
    let task = session.dataTask(with: request)

    let stream = AsyncThrowingStream<Data, Error> { continuation in
      delegate.streamContinuation = continuation
    }

    let response = try await withCheckedThrowingContinuation { continuation in
      delegate.responseContinuation = continuation
      task.resume()
    }

    return (stream, response as! HTTPURLResponse)
  }
}

fileprivate class Delegate: NSObject, URLSessionDataDelegate {
  var responseContinuation: CheckedContinuation<URLResponse, Error>?
  var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?

  private var buffer: Data = Data()
  private let bufferFlushSize = 16 * 1024 * 1024

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    // Soft-limit for the maximum buffer capacity
    let capacity = min(response.expectedContentLength, Int64(bufferFlushSize))

    // Pre-initialize buffer as we now know the capacity
    buffer = Data(capacity: Int(capacity))

    responseContinuation?.resume(returning: response)
    completionHandler(.allow)
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    buffer.append(data)

    if buffer.count >= bufferFlushSize {
      streamContinuation?.yield(buffer)
      buffer.removeAll(keepingCapacity: true)
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if !buffer.isEmpty {
      streamContinuation?.yield(buffer)
      buffer.removeAll(keepingCapacity: true)
    }

    if let error = error {
      streamContinuation?.finish(throwing: error)
    } else {
      streamContinuation?.finish()
    }
  }
}
