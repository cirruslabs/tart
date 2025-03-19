import Foundation

class Fetcher {
  let urlSession: URLSession
  let caCert: SecCertificate?

  init(proxy: String? = nil, caCert: String? = nil) throws {
    // Configure URLSession
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

    if let proxy {
      let (host, port) = try Self.parseProxy(proxy)

      config.connectionProxyDictionary = [
        kCFNetworkProxiesHTTPEnable: true,
        kCFNetworkProxiesHTTPProxy: host,
        kCFNetworkProxiesHTTPPort: port,

        kCFNetworkProxiesHTTPSEnable: true,
        kCFNetworkProxiesHTTPSProxy: host,
        kCFNetworkProxiesHTTPSPort: port,
      ]
    }

    self.urlSession = URLSession(configuration: config)

    // Load CA certificate, if any
    if let caCert {
      let caCertString = try String(contentsOf: URL(filePath: caCert), encoding:. utf8)

      let caCertBase64Lines = caCertString.components(separatedBy: .newlines).filter { line in
        !line.hasPrefix("-----BEGIN") && !line.hasPrefix("-----END")
      }

      guard let caCertData = Data(base64Encoded: caCertBase64Lines.joined()) else {
        throw RuntimeError.FailedToLoadCACertificate("failed to parse Base64-encoded PEM data")
      }

      self.caCert = SecCertificateCreateWithData(nil, caCertData as CFData)!
    } else {
      self.caCert = nil
    }
  }

  func fetch(_ request: URLRequest, viaFile: Bool = false) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
    let task = self.urlSession.dataTask(with: request)

    let delegate = Delegate(caCert: self.caCert)
    task.delegate = delegate

    let stream = AsyncThrowingStream<Data, Error> { continuation in
      delegate.streamContinuation = continuation
    }

    let response = try await withCheckedThrowingContinuation { continuation in
      delegate.responseContinuation = continuation
      task.resume()
    }

    return (stream, response as! HTTPURLResponse)
  }

  private static func parseProxy(_ proxy: String) throws -> (String, Int) {
    // Assume that the scheme is specified
    var url = URL(string: proxy)

    // Fall back to HTTP scheme when not specified
    if url?.scheme == nil {
      url = URL(string: "http://\(proxy)")
    }

    guard let url else {
      throw RuntimeError.InvalidProxyString
    }

    guard let host = url.host() else {
      throw RuntimeError.InvalidProxyString
    }

    guard let port = url.port else {
      throw RuntimeError.InvalidProxyString
    }

    return (host, port)
  }
}

fileprivate class Delegate: NSObject, URLSessionDelegate, URLSessionDataDelegate {
  let caCert: SecCertificate?
  var responseContinuation: CheckedContinuation<URLResponse, Error>?
  var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?

  private var buffer: Data = Data()
  private let bufferFlushSize = 16 * 1024 * 1024

  init(caCert: SecCertificate?) {
    self.caCert = caCert
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    if let caCert {
      // Ensure that we're performing server trust authentication
      guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust else {
        completionHandler(.performDefaultHandling, nil)

        return
      }

      // Set the provided CA certificate as the only anchor
      if SecTrustSetAnchorCertificates(serverTrust, [caCert] as CFArray) != errSecSuccess {
        completionHandler(.cancelAuthenticationChallenge, nil)

        return
      }

      // Evaluate the trust
      if SecTrustEvaluateWithError(serverTrust, nil) {
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
      } else {
        completionHandler(.rejectProtectionSpace, nil)
      }

      return
    }

    completionHandler(.performDefaultHandling, nil)
  }

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
    responseContinuation = nil
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
    if let error = error {
      responseContinuation?.resume(throwing: error)
      responseContinuation = nil

      streamContinuation?.finish(throwing: error)
      streamContinuation = nil
    } else {
      if !buffer.isEmpty {
        streamContinuation?.yield(buffer)
        buffer.removeAll(keepingCapacity: true)
      }

      streamContinuation?.finish()
      streamContinuation = nil
    }
  }
}
