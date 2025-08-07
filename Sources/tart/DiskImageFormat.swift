import Foundation
import ArgumentParser

enum DiskImageFormat: String, CaseIterable, Codable {
  case raw = "raw"
  case asif = "asif"

  var displayName: String {
    switch self {
    case .raw:
      return "RAW"
    case .asif:
      return "ASIF (Apple Sparse Image Format)"
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


}

extension DiskImageFormat: ExpressibleByArgument {
  init?(argument: String) {
    self.init(rawValue: argument.lowercased())
  }

  static var allValueStrings: [String] {
    return allCases.map { $0.rawValue }
  }
}
