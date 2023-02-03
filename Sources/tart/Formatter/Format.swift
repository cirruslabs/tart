import ArgumentParser
import Foundation
import TextTable

enum Format: String, EnumerableFlag {
  case table, json

  func renderSingle<T>(_ data: T) -> String where T: Encodable {
    switch self {
    case .table:
      return renderList([data])
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try! encoder.encode(data).asText()
    }
  }

  func renderList<T>(_ data: Array<T>) -> String where T: Encodable {
    switch self {
    case .table:
      if (data.count == 0) {
        return ""
      }
      let table = TextTable<T> { (item: T) in
        let mirroredObject = Mirror(reflecting: item)
        return mirroredObject.children.enumerated().map { (_, element) in
          let fieldName = element.label!
          return Column(title: fieldName, value: element.value)
        }
      }
      return table.string(for: data, style: Style.plain) ?? ""
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try! encoder.encode(data).asText()
    }
  }
}
