import Foundation
import Parsing

struct Reference: Comparable, Hashable, CustomStringConvertible {
  enum ReferenceType: Comparable {
    case Tag
    case Digest
  }

  let type: ReferenceType
  let value: String

  var fullyQualified: String {
    get {
      switch type {
      case .Tag:
        return ":" + value
      case .Digest:
        return "@" + value
      }
    }
  }

  init(tag: String) {
    type = .Tag
    value = tag
  }

  init(digest: String) {
    type = .Digest
    value = digest
  }

  static func <(lhs: Reference, rhs: Reference) -> Bool {
    if lhs.type != rhs.type {
      return lhs.type < rhs.type
    } else {
      return lhs.value < rhs.value
    }
  }

  var description: String {
    get {
      fullyQualified
    }
  }
}

struct RemoteName: Comparable, Hashable, CustomStringConvertible {
  var host: String
  var namespace: String
  var reference: Reference

  init(host: String, namespace: String, reference: Reference) {
    self.host = host
    self.namespace = namespace
    self.reference = reference
  }

  init(_ name: String) throws {
    let csNormal = [
      UInt8(ascii: "a")...UInt8(ascii: "z"),
      UInt8(ascii: "A")...UInt8(ascii: "Z"),
      UInt8(ascii: "0")...UInt8(ascii: "9"),
    ].asCharacterSet().union(CharacterSet(charactersIn: "_-."))

    let csHex = [
      UInt8(ascii: "a")...UInt8(ascii: "f"),
      UInt8(ascii: "0")...UInt8(ascii: "9"),
    ].asCharacterSet()

    let parser = Parse {
      Consumed {
        csNormal
        Optionally {
          ":"
          Digits()
        }
      }
      "/"
      csNormal.union(CharacterSet(charactersIn: "/"))
      Optionally {
        OneOf {
          Parse {
            ":"
            csNormal.map {
              Reference(tag: String($0))
            }
          }
          Parse {
            "@sha256:"
            csHex.map {
              Reference(digest: "sha256:" + String($0))
            }
          }
        }
      }
      End()
    }

    let result = try parser.parse(name)

    host = String(result.0)
    namespace = String(result.1)
    reference = result.2 ?? Reference(tag: "latest")
  }

  static func <(lhs: RemoteName, rhs: RemoteName) -> Bool {
    if lhs.host != rhs.host {
      return lhs.host < rhs.host
    } else if lhs.namespace != rhs.namespace {
      return lhs.namespace < rhs.namespace
    } else {
      return lhs.reference < rhs.reference
    }
  }

  var description: String {
    "\(host)/\(namespace)\(reference.fullyQualified)"
  }
}

extension Array where Self.Element == ClosedRange<UInt8> {
  func asCharacterSet() -> CharacterSet {
    let characters = self.joined().map { String(UnicodeScalar($0)) }.joined()
    return CharacterSet(charactersIn: characters)
  }
}
