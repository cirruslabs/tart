import Foundation
import Parsing

struct Tail {
  enum TailType {
    case Tag
    case Digest
  }

  var type: TailType
  var value: String
}

struct RemoteName: Comparable, CustomStringConvertible {
  var host: String
  var namespace: String
  var reference: String = "latest"
  var fullyQualifiedReference: String {
    get {
      if reference.starts(with: "sha256:") {
        return "@" + reference
      }

      return ":" + reference
    }
  }

  init(host: String, namespace: String, reference: String) {
    self.host = host
    self.namespace = namespace
    self.reference = reference
  }

  init(_ name: String) throws {
    let csNormal = [
      UInt8(ascii: "a")...UInt8(ascii: "z"),
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
              Tail(type: .Tag, value: String($0))
            }
          }
          Parse {
            "@sha256:"
            csHex.map {
              Tail(type: .Digest, value: "sha256:" + String($0))
            }
          }
        }
      }
      End()
    }

    let result = try parser.parse(name)

    host = String(result.0)
    namespace = String(result.1)
    if let tail = result.2 {
      reference = tail.value
    }
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
    "\(host)/\(namespace)\(fullyQualifiedReference)"
  }
}

extension Array where Self.Element == ClosedRange<UInt8> {
  func asCharacterSet() -> CharacterSet {
    let characters = self.joined().map { String(UnicodeScalar($0)) }.joined()
    return CharacterSet(charactersIn: characters)
  }
}
