import Foundation

enum RegistryError: Error {
  case UnexpectedHTTPStatusCode(when: String, code: Int, details: String = "")
  case MissingLocationHeader
  case AuthFailed(why: String)
  case MalformedHeader(why: String)
}

struct TokenResponse: Decodable {
  var token: String
}

class Registry {
  var baseURL: URL
  var namespace: String
  var user: String
  var password: String

  var token: String? = nil

  init(host: String, namespace: String) throws {
    var baseURLComponents = URLComponents()
    baseURLComponents.scheme = "https"
    baseURLComponents.host = host
    baseURLComponents.path = "/v2/"

    baseURL = baseURLComponents.url!
    self.namespace = namespace
    (user, password) = try Credentials.retrieve(host: host)
  }

  func pushManifest(reference: String, config: Descriptor, layers: [OCIManifestLayer]) async throws -> String {
    let manifest = OCIManifest(config: OCIManifestConfig(size: config.size, digest: config.digest),
      layers: layers)
    let manifestJSON = try JSONEncoder().encode(manifest)

    let (responseData, response) = try await endpointRequest("PUT", "\(namespace)/manifests/\(reference)",
      headers: ["Content-Type": manifest.mediaType],
      body: manifestJSON)
    if response.statusCode != 201 {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing manifest", code: response.statusCode,
        details: String(decoding: responseData, as: UTF8.self))
    }

    return Digest.hash(manifestJSON)
  }

  public func pullManifest(reference: String) async throws -> (OCIManifest, Data) {
    let (responseData, response) = try await endpointRequest("GET", "\(namespace)/manifests/\(reference)",
      headers: ["Accept": ociManifestMediaType])
    if response.statusCode != 200 {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling manifest", code: response.statusCode,
        details: String(decoding: responseData, as: UTF8.self))
    }

    let manifest = try JSONDecoder().decode(OCIManifest.self, from: responseData)

    return (manifest, responseData)
  }

  private func uploadLocationFromResponse(response: HTTPURLResponse) throws -> URLComponents {
    guard let uploadLocationRaw = response.value(forHTTPHeaderField: "Location") else {
      throw RegistryError.MissingLocationHeader
    }

    var uploadLocation = URL(string: uploadLocationRaw)!

    // If the URL provided in the Location header
    // is relative — make it absolute.
    if uploadLocation.absoluteString == uploadLocation.relativeString {
      uploadLocation = URL(string: uploadLocation.path, relativeTo: baseURL)!
    }

    return URLComponents(url: uploadLocation, resolvingAgainstBaseURL: true)!
  }

  public func pushBlob(fromData: Data, chunkSize: Int = 5 * 1024 * 1024) async throws -> String {
    // Initiate a blob upload
    let (postData, postResponse) = try await endpointRequest("POST", "\(namespace)/blobs/uploads/",
      headers: ["Content-Length": "0"])
    if postResponse.statusCode != 202 {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (POST)", code: postResponse.statusCode,
        details: String(decoding: postData, as: UTF8.self))
    }

    // Figure out where to upload the blob
    let uploadLocation = try uploadLocationFromResponse(response: postResponse)

    // Upload the blob
    let headers = [
      "Content-Length": "\(fromData.count)",
      "Content-Type": "application/octet-stream",
    ]

    let digest = Digest.hash(fromData)
    let parameters = [
      "digest": digest,
    ]

    let (putData, putResponse) = try await rawRequest("PUT", uploadLocation, headers: headers, parameters: parameters,
      body: fromData)
    if putResponse.statusCode != 201 {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pushing blob (PUT)", code: putResponse.statusCode,
        details: String(decoding: putData, as: UTF8.self))
    }

    return digest
  }

  public func pullBlob(_ digest: String) async throws -> Data {
    let (putData, putResponse) = try await endpointRequest("GET", "\(namespace)/blobs/\(digest)")
    if putResponse.statusCode != 200 {
      throw RegistryError.UnexpectedHTTPStatusCode(when: "pulling blob", code: putResponse.statusCode,
        details: String(decoding: putData, as: UTF8.self))
    }

    return putData
  }

  private func endpointRequest(
    _ method: String,
    _ endpoint: String,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil
  ) async throws -> (Data, HTTPURLResponse) {
    let url = URL(string: endpoint, relativeTo: baseURL)!
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!

    return try await rawRequest(method, urlComponents, headers: headers, parameters: parameters, body: body)
  }

  private func rawRequest(
    _ method: String,
    _ urlComponents: URLComponents,
    headers: Dictionary<String, String> = Dictionary(),
    parameters: Dictionary<String, String> = Dictionary(),
    body: Data? = nil
  ) async throws -> (Data, HTTPURLResponse) {
    var urlComponents = urlComponents

    if !parameters.isEmpty {
      urlComponents.queryItems = Array()
    }
    urlComponents.queryItems?.append(contentsOf: parameters.map { key, value -> URLQueryItem in
      URLQueryItem(name: key, value: value)
    })

    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = method
    for (key, value) in headers {
      request.addValue(value, forHTTPHeaderField: key)
    }
    request.httpBody = body

    var (data, response) = try await authAwareRequest(request: request)

    if response.statusCode == 401 {
      try await auth(response: response)
      (data, response) = try await authAwareRequest(request: request)
    }

    return (data, response)
  }

  private func auth(response: HTTPURLResponse) async throws {
    // Process WWW-Authenticate header
    guard let wwwAuthenticateRaw = response.value(forHTTPHeaderField: "WWW-Authenticate") else {
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

    let encodedCredentials = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
    let headers = [
      "Authorization": "Basic \(encodedCredentials!)"
    ]

    let (responseData, response) = try await rawRequest("GET", authenticateURL, headers: headers)
    if response.statusCode != 200 {
      throw RegistryError.AuthFailed(why: "received unexpected HTTP status code \(response.statusCode)")
    }

    token = try JSONDecoder().decode(TokenResponse.self, from: responseData).token
  }

  private func authAwareRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    var request = request

    if let token = self.token {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let (responseData, response) = try await URLSession.shared.data(for: request)

    return (responseData, response as! HTTPURLResponse)
  }
}
