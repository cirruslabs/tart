import ArgumentParser
import Foundation
import TextTable

enum Format: String, ExpressibleByArgument, CaseIterable {
  case text, json

  private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}

  func renderSingle<T>(_ data: T) -> String where T: Encodable {
    switch self {
    case .text:
      return renderList([data])
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try! encoder.encode(data).asText()
    }
  }

  func renderList<T>(_ data: Array<T>) -> String where T: Encodable {
    switch self {
    case .text:
      if (data.count == 0) {
        return ""
      }
      let table = TextTable<T> { (item: T) in
        let mirroredObject = Mirror(reflecting: item)
        return mirroredObject.children.enumerated()
          .filter {(_, element) in
            // Deprecate the "Running" field: only make it available
            // from JSON for backwards-compatibility
            element.label! != "Running"
          }
          .map { (_, element) in
            let fieldName = element.label!
            return Column(title: fieldName, value: element.value)
          }
      }
      return table.string(for: data, style: Style.plain)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try! encoder.encode(data).asText()
    }
  }
}
