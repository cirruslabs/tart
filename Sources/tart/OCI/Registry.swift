import Foundation
import NIOCore
import NIOHTTP1
import AsyncHTTPClient

enum RegistryError: Error {
  case UnexpectedHTTPStatusCode(when: String, code: UInt, details: String = "")
  case MissingLocationHeader
  case AuthFailed(why: String, details: String = "")
  case MalformedHeader(why: String)
}

extension HTTPClientResponse.Body {
  func readTextResponse() async throws -> String? {
    let data = try await readResponse()
    return String(decoding: data, as: UTF8.self)
  }

  func readResponse() async throws -> Data {
    var result = Data()
    for try await part in self {
      result.append(Data(buffer: part))
    }
    return result
  }
}

struct TokenResponse: Decodable {
  static let defaultIssuedAt = Date()
  static let defaultExpiresIn = 60

  var token: String
  var expiresIn: Int?
  var issuedAt: Date?

  static func parse(fromData: Data) throws -> Self {
    let decoder = JSONDecoder()

    decoder.keyDecodingStrategy = .convertFromSnakeCase

    // RFC3339 date formatter from Apple's documentation[1]
    //
    // [1]: https://developer.apple.com/documentation/foundation/dateformatter
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    decoder.dateDecodingStrategy = .formatted(dateFormatter)

    return try decoder.decode(TokenResponse.self, from: fromData)
  }

  var tokenExpiresAt: Date {
    get {
      // Tokens can expire and expire_in field is used to determine when:
      //
      // >The duration in seconds since the token was issued that it will remain valid.
      // >When omitted, this defaults to 60 seconds. For compatibility with older clients,
      // >a token should never be returned with less than 60 seconds to live.
      //
      // [1]: https://docs.docker.com/registry/spec/auth/token/#requesting-a-token

      (issuedAt ?? TokenResponse.defaultIssuedAt) + TimeInterval(expiresIn ?? TokenResponse.defaultExpiresIn)
    }
  }

  var isValid: Bool {
    get {
      Date() < tokenExpiresAt
    }
  }
}

fileprivate let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

class Registry {
  var baseURL: URL
  var namespace: String

  var currentAuthToken: TokenResponse? = nil

  init(urlComponents: URLComponents, namespace: String) throws {
    baseURL = urlComponents.url!
    self.namespace = namespace
  }

  convenience init(host: String, namespace: String) throws {
    var baseURLComponents = URLComponents()

    baseURLComponents.scheme = "https"
    baseURLComponents.host = host
    baseURLComponents.path = "/v2/"

    try self.init(urlComponents: baseURLComponents, namespace: namespace)
  }

  func ping() async throws {
    let response = try await endpointRequest(.GET, "/v2/")
    if response.status != .ok {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "doing ping", code: response.status.code)
    }
  }

  func pushManifest(reference: String, manifest: OCIManifest) async throws -> String {
    let manifestJSON = try JSONEncoder().encode(manifest)

    let response = try await endpointRequest(.PUT, "\(namespace)/manifests/\(reference)",
      headers: ["Content-Type": manifest.mediaType],
      body: manifestJSON)
    if response.status != .created {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing manifest", code: response.status.code,
        details: try await response.body.readTextResponse() ?? "")
    }

    return Digest.hash(manifestJSON)
  }

  public func pullManifest(reference: String) async throws -> (OCIManifest, Data) {
    let response = try await endpointRequest(.GET, "\(namespace)/manifests/\(reference)",
      headers: ["Accept": ociManifestMediaType])
    if response.status != .ok {
      let body = try await response.body.readTextResponse()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling manifest", code: response.status.code,
        details: body ?? "")
    }

    let manifestData = try await response.body.readResponse()
    let manifest = try JSONDecoder().decode(OCIManifest.self, from: manifestData)

    return (manifest, manifestData)
  }

  private func uploadLocationFromResponse(_ response: HTTPClientResponse) throws -> URLComponents {
    guard let uploadLocationRaw = response.headers.first(name: "Location") else {
      throw RegistryError.MissingLocationHeader
    }

    guard let uploadLocation = URL(string: uploadLocationRaw) else {
      throw RegistryError.MalformedHeader(why: "Location header contains invalid URL: \"\(uploadLocationRaw)\"")
    }

    return URLComponents(url: uploadLocation.absolutize(baseURL), resolvingAgainstBaseURL: true)!
  }

  public func pushBlob(fromData: Data, chunkSize: Int = 5 * 1024 * 1024) async throws -> String {
    // Initiate a blob upload
    let postResponse = try await endpointRequest(.POST, "\(namespace)/blobs/uploads/",
      headers: ["Content-Length": "0"])
    if postResponse.status != .accepted {
      let body = try await postResponse.body.readTextResponse()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (POST)", code: postResponse.status.code,
        details: body ?? "")
    }

    // Figure out where to upload the blob
    let uploadLocation = try uploadLocationFromResponse(postResponse)

    // Upload the blob
    let headers = [
      "Content-Length": "\(fromData.count)",
      "Content-Type": "application/octet-stream",
    ]

    let digest = Digest.hash(fromData)
    let parameters = [
      "digest": digest,
    ]

    let putResponse = try await rawRequest(.PUT, uploadLocation, headers: headers, parameters: parameters,
      body: fromData)
    if putResponse.status != .created {
      let body = try await postResponse.body.readTextResponse()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (PUT)", code: putResponse.status.code,
        details: body ?? "")
    }

    return digest
  }

  public func pullBlob(_ digest: String, handler: (ByteBuffer) throws -> Void) async throws {
    let response = try await endpointRequest(.GET, "\(namespace)/blobs/\(digest)")
    if response.status != .ok {
      let body = try await response.body.readTextResponse()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling blob", code: response.status.code,
        details: body ?? "")
    }

    for try await part in response.body {
      try handler(part)
    }
  }

  private func endpointRequest(
    _ method: HTTPMethod,
    _ endpoint: String,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil
  ) async throws -> HTTPClientResponse {
    let url = URL(string: endpoint, relativeTo: baseURL)!
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!

    return try await rawRequest(method, urlComponents, headers: headers, parameters: parameters, body: body)
  }

  private func rawRequest(
    _ method: HTTPMethod,
    _ urlComponents: URLComponents,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil
  ) async throws -> HTTPClientResponse {
    var urlComponents = urlComponents

    if urlComponents.queryItems == nil {
      urlComponents.queryItems = []
    }
    urlComponents.queryItems?.append(contentsOf: parameters.map { key, value -> URLQueryItem in
      URLQueryItem(name: key, value: value)
    })

    var request = HTTPClientRequest(url: urlComponents.string!)
    request.method = method
    for (key, value) in headers {
      request.headers.add(name: key, value: value)
    }
    if body != nil {
      request.body = HTTPClientRequest.Body.bytes(body!)
    }

    // Invalidate token if it has expired
    if currentAuthToken?.isValid == false {
      currentAuthToken = nil
    }

    var response = try await authAwareRequest(request: request)

    if response.status == .unauthorized {
      try await auth(response: response)
      response = try await authAwareRequest(request: request)
    }

    return response
  }

  private func auth(response: HTTPClientResponse) async throws {
    // Process WWW-Authenticate header
    guard let wwwAuthenticateRaw = response.headers.first(name: "WWW-Authenticate") else {
      throw RegistryError.AuthFailed(why: "got HTTP 401, but WWW-Authenticate header is missing")
    }

    let wwwAuthenticate = try WWWAuthenticate(rawHeaderValue: wwwAuthenticateRaw)
    if wwwAuthenticate.scheme != "Bearer" {
      throw RegistryError.AuthFailed(why: "WWW-Authenticate header's authentication scheme "
        + "\"\(wwwAuthenticate.scheme)\" is unsupported, expected \"Bearer\" scheme")
    }
    guard let realm = wwwAuthenticate.kvs["realm"] else {
      throw RegistryError.AuthFailed(why: "WWW-Authenticate header is missing a \"realm\" directive")
    }

    // Request a token
    guard var authenticateURL = URLComponents(string: realm) else {
      throw RegistryError.AuthFailed(why: "WWW-Authenticate header's realm directive "
        + "\"\(realm)\" doesn't look like URL")
    }

    // Token Authentication Specification[1]:
    //
    // >To respond to this challenge, the client will need to make a GET request
    // >[...] using the service and scope values from the WWW-Authenticate header.
    //
    // [1]: https://docs.docker.com/registry/spec/auth/token/
    authenticateURL.queryItems = ["scope", "service"].compactMap { key in
      if let value = wwwAuthenticate.kvs[key] {
        return URLQueryItem(name: key, value: value)
      } else {
        return nil
      }
    }

    var headers: Dictionary<String, String> = Dictionary()

    if let (user, password) = try Credentials.retrieveKeychain(host: baseURL.host!) {
      let encodedCredentials = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
      headers["Authorization"] = "Basic \(encodedCredentials!)"
    }

    let response = try await rawRequest(.GET, authenticateURL, headers: headers)
    if response.status != .ok {
      let body = try await response.body.readTextResponse() ?? ""
      throw RegistryError.AuthFailed(why: "received unexpected HTTP status code \(response.status.code) "
        + "while retrieving an authentication token", details: body)
    }

    let bodyData = try await response.body.readResponse()
    currentAuthToken = try TokenResponse.parse(fromData: bodyData)
  }

  private func authAwareRequest(request: HTTPClientRequest) async throws -> HTTPClientResponse {
    var request = request

    if let token = currentAuthToken {
      request.headers.add(name: "Authorization", value: "Bearer \(token.token)")
    }

    return try await httpClient.execute(request, deadline: .distantFuture)
  }
}
