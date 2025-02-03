import Foundation

extension Collection {
  subscript (safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

func resolveBinaryPath(_ name: String) -> URL? {
  guard let path = ProcessInfo.processInfo.environment["PATH"] else {
    return nil
  }

  for pathComponent in path.split(separator: ":") {
    let url = URL(fileURLWithPath: String(pathComponent))
      .appendingPathComponent(name, isDirectory: false)

    if FileManager.default.fileExists(atPath: url.path) {
      return url
    }
  }

  return nil
}

// MARK: - Protocols for system interfaces to make them mockable

// MARK: ProcessInfo
/// A protocol resembling required interfaces of `ProcessInfo`.
protocol ProcessInformation {
  /// The variable names (keys) and their values in the environment from which the process was launched.
  var environment: [String : String] { get }
}

extension ProcessInfo: ProcessInformation { }

// MARK: FileManager
protocol FileManaging {
  /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
  func fileExists(atPath path: String) -> Bool

  /// Returns the Data contents of the file at the given `url`. Uses `Data(contentsOf:options:)`.
  func data(contentsOf url: URL, options: Data.ReadingOptions) throws -> Data
}

extension FileManaging {
  /// Returns the Data contents of the file at the given `url`. Uses `Data(contentsOf:options:)`.
  func data(contentsOf url: URL) throws -> Data {
    return try data(contentsOf: url, options: [])
  }
}

extension FileManager: FileManaging {
  func data(contentsOf url: URL, options: Data.ReadingOptions) throws -> Data {
    return try Data(contentsOf: url, options: options)
  }
}
