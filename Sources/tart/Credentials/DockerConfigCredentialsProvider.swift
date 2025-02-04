import Foundation

class DockerConfigCredentialsProvider: CredentialsProvider {

  func retrieve(host: String) throws -> (String, String)? {
    guard let config = try configFromEnvironment() ?? (try configFromFileSystem()) else {
      return nil
    }

    return try retrieveCredentials(for: host, from: config)
  }

  // MARK: - Private
  private func retrieveCredentials(for host: String, from config: DockerConfig) throws -> (String, String)? {
    if let credentials = config.auths?[host]?.decodeCredentials() {
      return credentials
    }

    if let helperProgram = try config.findCredHelper(host: host) {
      return try executeHelper(binaryName: "docker-credential-\(helperProgram)", host: host)
    }

    return nil
  }

  private func configFromEnvironment() throws -> DockerConfig? {
    guard let configJson = ProcessInfo.processInfo.environment["TART_DOCKER_AUTH_CONFIG"]?.data(using: .utf8) else {
      return nil
    }

    return try JSONDecoder().decode(DockerConfig.self, from: configJson)
  }

  private func configFromFileSystem() throws -> DockerConfig? {
    let dockerConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".docker").appendingPathComponent("config.json")

    if !FileManager.default.fileExists(atPath: dockerConfigURL.path) {
      return nil
    }

    return try JSONDecoder().decode(DockerConfig.self, from: Data(contentsOf: dockerConfigURL))
  }

  private func executeHelper(binaryName: String, host: String) throws -> (String, String)? {
    guard let executableURL = resolveBinaryPath(binaryName) else {
      throw CredentialsProviderError.Failed(message: "\(binaryName) not found in PATH")
    }

    let process = Process.init()
    process.executableURL = executableURL
    process.arguments = ["get"]

    let outPipe = Pipe()
    let inPipe = Pipe()

    process.standardOutput = outPipe
    process.standardError = outPipe
    process.standardInput = inPipe

    process.launch()

    do {
      try inPipe.fileHandleForWriting.write(contentsOf: "\(host)\n".data(using: .utf8)!)
    } catch {
      throw CredentialsProviderError.Failed(message: "Failed to write host to Docker helper!")
    }
    inPipe.fileHandleForWriting.closeFile()

    let outputData = try outPipe.fileHandleForReading.readToEnd()

    process.waitUntilExit()

    if !(process.terminationReason == .exit && process.terminationStatus == 0) {
      if let outputData = outputData {
        print(String(decoding: outputData, as: UTF8.self))
      }
      throw CredentialsProviderError.Failed(message: "Docker helper failed!")
    }
    if outputData == nil || outputData?.count == 0 {
      throw CredentialsProviderError.Failed(message: "Docker helper output is empty!")
    }

    let getOutput = try JSONDecoder().decode(DockerGetOutput.self, from: outputData!)
    return (getOutput.Username, getOutput.Secret)
  }

  func store(host: String, user: String, password: String) throws {
    throw CredentialsProviderError.Failed(message: "Docker helpers don't support storing!")
  }
}

struct DockerConfig: Codable {
  var auths: Dictionary<String, DockerAuthConfig>? = Dictionary()
  var credHelpers: Dictionary<String, String>? = Dictionary()

  func findCredHelper(host: String) throws -> String? {
    // Tart supports wildcards in credHelpers
    // Similar to what is requested from Docker: https://github.com/docker/cli/issues/2928

    guard let credHelpers else {
      return nil
    }

    for (hostPattern, helperProgram) in credHelpers {
      if (hostPattern == host) {
        return helperProgram
      }
      let compiledPattern = try? Regex(hostPattern)
      if (try compiledPattern?.wholeMatch(in: host) != nil) {
        return helperProgram
      }
    }
    return nil
  }
}

struct DockerAuthConfig: Codable {
  var auth: String? = nil

  func decodeCredentials() -> (String, String)? {
    // auth is a base64("username:password")
    guard let authBase64 = auth else {
      return nil
    }
    guard let data = Data(base64Encoded: authBase64) else {
      return nil
    }
    guard let components = String(data: data, encoding: .utf8)?.components(separatedBy: ":") else {
      return nil
    }
    if components.count != 2 {
      return nil
    }
    return (components[0], components[1])
  }
}

struct DockerGetOutput: Codable {
  var Username: String
  var Secret: String
}
