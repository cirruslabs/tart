import Foundation

// WWW-Authenticate header parser based on details from RFCs[1][2]
///
// [1]: https://www.rfc-editor.org/rfc/rfc2617#section-3.2.1
// [2]: https://www.rfc-editor.org/rfc/rfc6750#section-3
class WWWAuthenticate {
  var scheme: String
  var kvs: Dictionary<String, String> = Dictionary()

  init(rawHeaderValue: String) throws {
    let splits = rawHeaderValue.split(separator: " ", maxSplits: 2)

    if splits.count >= 1 {
      scheme = String(splits[0])
    } else {
      throw RegistryError.MalformedHeader
    }

    let rawDirectives = contextAwareSplit(rawDirectives: String(splits[1]))

    try rawDirectives.forEach { sequence in
      let parts = sequence.split(separator: "=")
      if parts.count != 2 {
        throw RegistryError.MalformedHeader
      }

      let key = String(parts[0])
      var value = String(parts[1])
      value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

      kvs[key] = value
    }
  }

  private func contextAwareSplit(rawDirectives: String) -> Array<String> {
    var result: Array<String> = Array()
    var inQuotation: Bool = false
    var accumulator: Array<Character> = Array()

    for ch in rawDirectives {
      if ch == "," && !inQuotation {
        result.append(String(accumulator))
        accumulator.removeAll()
        continue
      }

      accumulator.append(ch)

      if ch == "\"" {
        inQuotation.toggle()
      }
    }

    if !accumulator.isEmpty {
      result.append(String(accumulator))
    }

    return result
  }
}
