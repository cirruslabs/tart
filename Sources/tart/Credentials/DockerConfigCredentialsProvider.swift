import Foundation

class DockerConfigCredentialsProvider: CredentialsProvider {
  func retrieve(host: String) throws -> (String, String)? {
    let dockerConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".docker").appendingPathComponent("config.json")
    if !FileManager.default.fileExists(atPath: dockerConfigURL.path) {
      return nil
    }
    let config = try JSONDecoder().decode(DockerConfig.self, from: Data(contentsOf: dockerConfigURL))

    if let credentialsFromAuth = config.auths?[host]?.decodeCredentials() {
      return credentialsFromAuth
    }
    if let helperProgram = config.credHelpers?[host] {
      return try executeHelper(binaryName: "docker-credential-\(helperProgram)", host: host)
    }

    return nil
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

    inPipe.fileHandleForWriting.write("\(host)\n".data(using: .utf8)!)
    inPipe.fileHandleForWriting.closeFile()
    
    process.waitUntilExit()

    if !(process.terminationReason == .exit && process.terminationStatus == 0) {
      throw CredentialsProviderError.Failed(message: "Docker helper failed!")
    }

    let getOutput = try JSONDecoder().decode(
      DockerGetOutput.self, from: outPipe.fileHandleForReading.readDataToEndOfFile()
    )
    return (getOutput.Username, getOutput.Secret)
  }

  func store(host: String, user: String, password: String) throws {
    throw CredentialsProviderError.Failed(message: "Docker helpers don't support storing!")
  }
}

struct DockerConfig: Codable {
  var auths: Dictionary<String, DockerAuthConfig>? = Dictionary()
  var credHelpers: Dictionary<String, String>? = Dictionary()
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
