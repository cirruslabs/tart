import Foundation
import Algorithms
import AsyncAlgorithms

let chunkSizeBytes = 1 * 1024 * 1024

enum RegistryError: Error {
  case UnexpectedHTTPStatusCode(when: String, code: Int, details: String = "")
  case MissingLocationHeader
  case AuthFailed(why: String, details: String = "")
  case MalformedHeader(why: String)
}

enum HTTPMethod: String {
  case GET = "GET"
  case POST = "POST"
  case PUT = "PUT"
  case PATCH = "PATCH"
}

enum HTTPCode: Int {
  case Ok = 200
  case Created = 201
  case Accepted = 202
  case Unauthorized = 401
}

extension Data {
  func asText() async throws -> String? {
    String(decoding: self, as: UTF8.self)
  }
}

extension URLSession.AsyncBytes {
  func asData() async throws -> Data {
    var result = Data()

    for try await chunk in chunks(ofCount: chunkSizeBytes) {
      result += chunk
    }

    return result
  }
}

struct TokenResponse: Decodable, Authentication {
  let defaultIssuedAt = Date()
  let defaultExpiresIn = 60

  var token: String
  var expiresIn: Int?
  var issuedAt: Date?

  static func parse(fromData: Data) throws -> Self {
    let decoder = Config.jsonDecoder()

    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let dateString = try container.decode(String.self)

      return dateFormatter.date(from: dateString) ?? Date()
    }

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

      (issuedAt ?? defaultIssuedAt) + TimeInterval(expiresIn ?? defaultExpiresIn)
    }
  }

  func header() -> (String, String) {
    ("Authorization", "Bearer \(token)")
  }

  func isValid() -> Bool {
    Date() < tokenExpiresAt
  }
}

class Registry {
  let baseURL: URL
  let namespace: String
  let credentialsProviders: [CredentialsProvider]

  var currentAuthToken: Authentication? = nil

  init(urlComponents: URLComponents,
       namespace: String,
       credentialsProviders: [CredentialsProvider] = [DockerConfigCredentialsProvider(), KeychainCredentialsProvider()]
  ) throws {
    baseURL = urlComponents.url!
    self.namespace = namespace
    self.credentialsProviders = credentialsProviders
  }

  convenience init(
    host: String,
    namespace: String,
    insecure: Bool = false,
    credentialsProviders: [CredentialsProvider] = [DockerConfigCredentialsProvider(), KeychainCredentialsProvider()]
  ) throws {
    let proto = insecure ? "http" : "https"
    let baseURLComponents = URLComponents(string: proto + "://" + host + "/v2/")!

    try self.init(urlComponents: baseURLComponents, namespace: namespace, credentialsProviders: credentialsProviders)
  }

  func ping() async throws {
    let (_, response) = try await endpointRequest(.GET, "/v2/")
    if response.statusCode != HTTPCode.Ok.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "doing ping", code: response.statusCode)
    }
  }

  func pushManifest(reference: String, manifest: OCIManifest) async throws -> String {
    let manifestJSON = try manifest.toJSON()

    let (bytes, response) = try await endpointRequest(.PUT, "\(namespace)/manifests/\(reference)",
      headers: ["Content-Type": manifest.mediaType],
      body: manifestJSON)
    if response.statusCode != HTTPCode.Created.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing manifest", code: response.statusCode,
        details: try await bytes.asData().asText() ?? "")
    }

    return Digest.hash(manifestJSON)
  }

  public func pullManifest(reference: String) async throws -> (OCIManifest, Data) {
    let (bytes, response) = try await endpointRequest(.GET, "\(namespace)/manifests/\(reference)",
      headers: ["Accept": ociManifestMediaType])
    if response.statusCode != HTTPCode.Ok.rawValue {
      let body = try await bytes.asData().asText()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling manifest", code: response.statusCode,
        details: body ?? "")
    }

    let manifestData = try await bytes.asData()
    let manifest = try OCIManifest(fromJSON: manifestData)

    return (manifest, manifestData)
  }

  private func uploadLocationFromResponse(_ response: HTTPURLResponse) throws -> URLComponents {
    guard let uploadLocationRaw = response.value(forHTTPHeaderField: "Location") else {
      throw RegistryError.MissingLocationHeader
    }

    guard let uploadLocation = URL(string: uploadLocationRaw) else {
      throw RegistryError.MalformedHeader(why: "Location header contains invalid URL: \"\(uploadLocationRaw)\"")
    }

    return URLComponents(url: uploadLocation.absolutize(baseURL), resolvingAgainstBaseURL: true)!
  }

  public func pushBlob(fromData: Data, chunkSizeMb: Int = 0) async throws -> String {
    // Initiate a blob upload
    let (bytes, postResponse) = try await endpointRequest(.POST, "\(namespace)/blobs/uploads/",
      headers: ["Content-Length": "0"])
    if postResponse.statusCode != HTTPCode.Accepted.rawValue {
      let body = try await bytes.asData().asText()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (POST)", code: postResponse.statusCode,
        details: body ?? "")
    }

    // Figure out where to upload the blob
    var uploadLocation = try uploadLocationFromResponse(postResponse)

    let digest = Digest.hash(fromData)
    
    if chunkSizeMb == 0 {
      // monolithic upload
      let (bytes, response) = try await rawRequest(
        .PUT,
        uploadLocation,
        headers: [
          "Content-Type": "application/octet-stream",
        ],
        parameters: ["digest": digest],
        body: fromData
      )
      if response.statusCode != HTTPCode.Created.rawValue {
        let body = try await bytes.asData().asText()
        throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (PUT) to \(uploadLocation)",
          code: response.statusCode, details: body ?? "")
      }
      return digest
    }

    // chunked upload
    var uploadedBytes = 0
    let chunks = fromData.chunks(ofCount: chunkSizeMb == 0 ? fromData.count : chunkSizeMb * 1_000_000)
    for (index, chunk) in chunks.enumerated() {
      let lastChunk = index == (chunks.count - 1)
      let (bytes, response) = try await rawRequest(
        lastChunk ? .PUT : .PATCH, 
        uploadLocation,
        headers: [
          "Content-Type": "application/octet-stream",
          "Content-Range": "\(uploadedBytes)-\(uploadedBytes + chunk.count - 1)",
        ],
        parameters: lastChunk ? ["digest": digest] : [:],
        body: chunk
      )
      let expectedStatus = lastChunk ? HTTPCode.Created.rawValue : HTTPCode.Accepted.rawValue
      if response.statusCode != expectedStatus {
        let body = try await bytes.asData().asText()
        throw RegistryError.UnexpectedHTTPStatusCode(when: "streaming blob to \(uploadLocation)",
          code: response.statusCode, details: body ?? "")
      }
      uploadedBytes += chunk.count
      // Update location for the next chunk
      uploadLocation = try uploadLocationFromResponse(response)
    }
    
    return digest
  }

  public func pullBlob(_ digest: String, handler: (Data) throws -> Void) async throws {
    let (bytes, response) = try await endpointRequest(.GET, "\(namespace)/blobs/\(digest)")
    if response.statusCode != HTTPCode.Ok.rawValue {
      let body = try await bytes.asData().asText()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling blob", code: response.statusCode,
        details: body ?? "")
    }

    for try await part in bytes.chunks(ofCount: chunkSizeBytes) {
      try Task.checkCancellation()

      try handler(Data(part))
    }
  }

  private func endpointRequest(
    _ method: HTTPMethod,
    _ endpoint: String,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil
  ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
    let url = URL(string: endpoint, relativeTo: baseURL)!
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!

    return try await rawRequest(method, urlComponents, headers: headers, parameters: parameters, body: body)
  }

  private func rawRequest(
    _ method: HTTPMethod,
    _ urlComponents: URLComponents,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil,
    doAuth: Bool = true
  ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
    var urlComponents = urlComponents

    if urlComponents.queryItems == nil && !parameters.isEmpty {
      urlComponents.queryItems = []
    }
    urlComponents.queryItems?.append(contentsOf: parameters.map { key, value -> URLQueryItem in
      URLQueryItem(name: key, value: value)
    })

    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = method.rawValue
    for (key, value) in headers {
      request.addValue(value, forHTTPHeaderField: key)
    }
    if let body = body {
      request.addValue("\(body.count)", forHTTPHeaderField: "Content-Length")
      request.httpBody = body
    }

    // Invalidate token if it has expired
    if currentAuthToken?.isValid() == false {
      currentAuthToken = nil
    }

    var (bytes, response) = try await authAwareRequest(request: request)

    if doAuth && response.statusCode == HTTPCode.Unauthorized.rawValue {
      try await auth(response: response)
      (bytes, response) = try await authAwareRequest(request: request)
    }

    return (bytes, response)
  }

  private func auth(response: HTTPURLResponse) async throws {
    // Process WWW-Authenticate header
    guard let wwwAuthenticateRaw = response.value(forHTTPHeaderField: "WWW-Authenticate") else {
      throw RegistryError.AuthFailed(why: "got HTTP 401, but WWW-Authenticate header is missing")
    }

    let wwwAuthenticate = try WWWAuthenticate(rawHeaderValue: wwwAuthenticateRaw)

    if wwwAuthenticate.scheme == "Basic" {
      if let (user, password) = try lookupCredentials(host: baseURL.host!) {
        currentAuthToken = BasicAuthentication(user: user, password: password)
      }

      return
    }

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

    if let (user, password) = try lookupCredentials(host: baseURL.host!) {
      let encodedCredentials = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
      headers["Authorization"] = "Basic \(encodedCredentials!)"
    }

    let (bytes, response) = try await rawRequest(.GET, authenticateURL, headers: headers, doAuth: false)
    if response.statusCode != HTTPCode.Ok.rawValue {
      let body = try await bytes.asData() .asText() ?? ""
      throw RegistryError.AuthFailed(why: "received unexpected HTTP status code \(response.statusCode) "
        + "while retrieving an authentication token", details: body)
    }

    let bodyData = try await bytes.asData()
    currentAuthToken = try TokenResponse.parse(fromData: bodyData)
  }

  private func lookupCredentials(host: String) throws -> (String, String)? {
    for provider in credentialsProviders {
      if let (user, password) = try provider.retrieve(host: host) {
        return (user, password)
      }
    }
    return nil
  }

  private func authAwareRequest(request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
    var request = request

    if let token = currentAuthToken {
      let (name, value) = token.header()
      request.addValue(value, forHTTPHeaderField: name)
    }

    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    return (bytes, response as! HTTPURLResponse)
  }
}
