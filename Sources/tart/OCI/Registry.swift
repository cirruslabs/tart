import Foundation
import Algorithms
import AsyncAlgorithms

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
  func asText() -> String {
    String(decoding: self, as: UTF8.self)
  }
}

extension AsyncThrowingChannel<Data, Error> {
  func asData() async throws -> Data {
    var result = Data()

    for try await chunk in self {
      result += chunk
    }

    return result
  }
}

struct TokenResponse: Decodable, Authentication {
  let defaultIssuedAt = Date()
  let defaultExpiresIn = 60

  var token: String?
  var accessToken: String?
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

    let response = try decoder.decode(TokenResponse.self, from: fromData)

    guard response.token != nil || response.accessToken != nil else {
      throw DecodingError.keyNotFound(CodingKeys.token, .init(codingPath: [], debugDescription: "Missing token or access_token. One must be present."))
    }

    return response
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
    return ("Authorization", "Bearer \(token ?? accessToken ?? "")")
  }

  func isValid() -> Bool {
    Date() < tokenExpiresAt
  }
}

class Registry {
  private let baseURL: URL
  let namespace: String
  let credentialsProviders: [CredentialsProvider]
  let authenticationKeeper = AuthenticationKeeper()

  var host: String? {
    guard let host = baseURL.host else { return nil }

    if let port = baseURL.port {
      return "\(host):\(port)"
    }

    return host
  }

  init(urlComponents: URLComponents,
       namespace: String,
       credentialsProviders: [CredentialsProvider] = [EnvironmentCredentialsProvider(), DockerConfigCredentialsProvider(), KeychainCredentialsProvider()]
  ) throws {
    baseURL = urlComponents.url!
    self.namespace = namespace
    self.credentialsProviders = credentialsProviders
  }

  convenience init(
    host: String,
    namespace: String,
    insecure: Bool = false,
    credentialsProviders: [CredentialsProvider] = [EnvironmentCredentialsProvider(), DockerConfigCredentialsProvider(), KeychainCredentialsProvider()]
  ) throws {
    let proto = insecure ? "http" : "https"
    let baseURLComponents = URLComponents(string: proto + "://" + host + "/v2/")!

    try self.init(urlComponents: baseURLComponents, namespace: namespace, credentialsProviders: credentialsProviders)
  }

  func ping() async throws {
    let (_, response) = try await dataRequest(.GET, endpointURL("/v2/"))
    if response.statusCode != HTTPCode.Ok.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "doing ping", code: response.statusCode)
    }
  }

  func pushManifest(reference: String, manifest: OCIManifest) async throws -> String {
    let manifestJSON = try manifest.toJSON()

    let (data, response) = try await dataRequest(.PUT, endpointURL("\(namespace)/manifests/\(reference)"),
                                                 headers: ["Content-Type": manifest.mediaType],
                                                 body: manifestJSON)
    if response.statusCode != HTTPCode.Created.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing manifest", code: response.statusCode,
                                                   details: data.asText())
    }

    return Digest.hash(manifestJSON)
  }

  public func pullManifest(reference: String) async throws -> (OCIManifest, Data) {
    let (data, response) = try await dataRequest(.GET, endpointURL("\(namespace)/manifests/\(reference)"),
                                                 headers: ["Accept": ociManifestMediaType])
    if response.statusCode != HTTPCode.Ok.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling manifest", code: response.statusCode,
                                                   details: data.asText())
    }

    let manifest = try OCIManifest(fromJSON: data)

    return (manifest, data)
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
    let (data, postResponse) = try await dataRequest(.POST, endpointURL("\(namespace)/blobs/uploads/"),
                                                     headers: ["Content-Length": "0"])
    if postResponse.statusCode != HTTPCode.Accepted.rawValue {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (POST)", code: postResponse.statusCode,
                                                   details: data.asText())
    }

    // Figure out where to upload the blob
    var uploadLocation = try uploadLocationFromResponse(postResponse)

    let digest = Digest.hash(fromData)

    if chunkSizeMb == 0 {
      // monolithic upload
      let (data, response) = try await dataRequest(
        .PUT,
        uploadLocation,
        headers: [
          "Content-Type": "application/octet-stream",
        ],
        parameters: ["digest": digest],
        body: fromData
      )
      if response.statusCode != HTTPCode.Created.rawValue {
        throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (PUT) to \(uploadLocation)",
                                                     code: response.statusCode, details: data.asText())
      }
      return digest
    }

    // chunked upload
    var uploadedBytes = 0
    let chunks = fromData.chunks(ofCount: chunkSizeMb == 0 ? fromData.count : chunkSizeMb * 1_000_000)
    for (index, chunk) in chunks.enumerated() {
      let lastChunk = index == (chunks.count - 1)
      let (data, response) = try await dataRequest(
        lastChunk ? .PUT : .PATCH, 
        uploadLocation,
        headers: [
          "Content-Type": "application/octet-stream",
          "Content-Range": "\(uploadedBytes)-\(uploadedBytes + chunk.count - 1)",
        ],
        parameters: lastChunk ? ["digest": digest] : [:],
        body: chunk
      )
      // always accept both statuses since AWS ECR is not following specification
      if response.statusCode != HTTPCode.Created.rawValue && response.statusCode != HTTPCode.Accepted.rawValue {
        throw RegistryError.UnexpectedHTTPStatusCode(when: "streaming blob to \(uploadLocation)",
                                                     code: response.statusCode, details: data.asText())
      }
      uploadedBytes += chunk.count
      // Update location for the next chunk
      uploadLocation = try uploadLocationFromResponse(response)
    }

    return digest
  }

  public func pullBlob(_ digest: String, handler: (Data) async throws -> Void) async throws {
    let (channel, response) = try await channelRequest(.GET, endpointURL("\(namespace)/blobs/\(digest)"), viaFile: true)
    if response.statusCode != HTTPCode.Ok.rawValue {
      let body = try await channel.asData().asText()
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling blob", code: response.statusCode,
                                                   details: body)
    }

    for try await part in channel {
      try Task.checkCancellation()

      try await handler(part)
    }
  }

  private func endpointURL(_ endpoint: String) -> URLComponents {
    let url = URL(string: endpoint, relativeTo: baseURL)!

    return URLComponents(url: url, resolvingAgainstBaseURL: true)!
  }

  private func dataRequest(
    _ method: HTTPMethod,
    _ urlComponents: URLComponents,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil,
    doAuth: Bool = true
  ) async throws -> (Data, HTTPURLResponse) {
    let (channel, response) = try await channelRequest(method, urlComponents,
                                                       headers: headers, parameters: parameters, body: body, doAuth: doAuth)

    return (try await channel.asData(), response)
  }

  private func channelRequest(
    _ method: HTTPMethod,
    _ urlComponents: URLComponents,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil,
    doAuth: Bool = true,
    viaFile: Bool = false
  ) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
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

    var (channel, response) = try await authAwareRequest(request: request, viaFile: viaFile)

    if doAuth && response.statusCode == HTTPCode.Unauthorized.rawValue {
      _ = try await channel.asData()
      try await auth(response: response)
      (channel, response) = try await authAwareRequest(request: request, viaFile: viaFile)
    }

    return (channel, response)
  }

  private func auth(response: HTTPURLResponse) async throws {
    // Process WWW-Authenticate header
    guard let wwwAuthenticateRaw = response.value(forHTTPHeaderField: "WWW-Authenticate") else {
      throw RegistryError.AuthFailed(why: "got HTTP 401, but WWW-Authenticate header is missing")
    }

    let wwwAuthenticate = try WWWAuthenticate(rawHeaderValue: wwwAuthenticateRaw)

    if wwwAuthenticate.scheme.lowercased() == "basic" {
      if let (user, password) = try lookupCredentials() {
        await authenticationKeeper.set(BasicAuthentication(user: user, password: password))
      }

      return
    }

    if wwwAuthenticate.scheme.lowercased() != "bearer" {
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

    if let (user, password) = try lookupCredentials() {
      let encodedCredentials = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
      headers["Authorization"] = "Basic \(encodedCredentials!)"
    }

    let (data, response) = try await dataRequest(.GET, authenticateURL, headers: headers, doAuth: false)
    if response.statusCode != HTTPCode.Ok.rawValue {
      throw RegistryError.AuthFailed(why: "received unexpected HTTP status code \(response.statusCode) "
        + "while retrieving an authentication token", details: data.asText())
    }

    await authenticationKeeper.set(try TokenResponse.parse(fromData: data))
  }

  private func lookupCredentials() throws -> (String, String)? {
    var host = baseURL.host!

    if let port = baseURL.port {
      host += ":\(port)"
    }

    for provider in credentialsProviders {
      if let (user, password) = try provider.retrieve(host: host) {
        return (user, password)
      }
    }
    return nil
  }

  private func authAwareRequest(request: URLRequest, viaFile: Bool = false) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
    var request = request

    if let (name, value) = await authenticationKeeper.header() {
      request.addValue(value, forHTTPHeaderField: name)
    }

    request.setValue("Tart/\(CI.version) (\(DeviceInfo.os); \(DeviceInfo.model))",
                     forHTTPHeaderField: "User-Agent")

    return try await Fetcher.fetch(request, viaFile: viaFile)
  }
}
