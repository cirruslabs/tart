import Foundation
import ArgumentParser

enum DiskImageFormat: String, CaseIterable, Codable {
  case raw = "raw"
  case asif = "asif"

  var displayName: String {
    switch self {
    case .raw:
      return "RAW (UDIF read-write)"
    case .asif:
      return "ASIF (Apple Sparse Image Format)"
    }
  }

  var description: String {
    switch self {
    case .raw:
      return "Traditional disk image format, compatible with all macOS versions"
    case .asif:
      return "High-performance sparse disk image format, requires macOS 15+ (creation requires macOS 26+)"
    }
  }

  /// Check if the format is supported on the current system
  var isSupported: Bool {
    switch self {
    case .raw:
      return true
    case .asif:
      if #available(macOS 15, *) {
        return true
      } else {
        return false
      }
    }
  }

  /// Check if the format can be created on the current system
  var canCreate: Bool {
    switch self {
    case .raw:
      return true
    case .asif:
      // ASIF creation requires diskutil with ASIF support (macOS 26+)
      return checkDiskutilASIFSupport()
    }
  }

  /// Check if diskutil supports ASIF format creation
  private func checkDiskutilASIFSupport() -> Bool {
    guard let diskutilURL = resolveBinaryPath("diskutil") else {
      return false
    }

    let process = Process()
    process.executableURL = diskutilURL
    process.arguments = ["image", "create", "blank", "--help"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""

      // Check if ASIF format is mentioned in the help output
      // Look for ASIF in the format options list
      return output.contains("ASIF") && output.contains("--format")
    } catch {
      return false
    }
  }
}

extension DiskImageFormat: ExpressibleByArgument {
  init?(argument: String) {
    self.init(rawValue: argument.lowercased())
  }

  static var allValueStrings: [String] {
    return allCases.map { $0.rawValue }
  }
}
