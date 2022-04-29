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

struct RemoteName: Comparable {
  var host: String
  var namespace: String
  var reference: String = "latest"

  init(host: String, namespace: String, reference: String) {
    self.host = host
    self.namespace = namespace
    self.reference = reference
  }

  init(_ name: String) throws {
    let alphas = UInt8(ascii: "a")...UInt8(ascii: "z")
    let digits = UInt8(ascii: "0")...UInt8(ascii: "9")
    let alphasDigitsCharacters = [alphas, digits].joined().map {
              String(UnicodeScalar($0))
            }
            .joined()
    let alphasDigits = CharacterSet(charactersIn: alphasDigitsCharacters)

    let parser = Parse {
      Consumed {
        alphasDigits.union(CharacterSet(charactersIn: "."))
        Optionally {
          ":"
          Digits()
        }
      }
      "/"
      alphasDigits.union(CharacterSet(charactersIn: "-/"))
      Optionally {
        OneOf {
          Parse {
            ":"
            alphasDigits.map {
              Tail(type: .Tag, value: String($0))
            }
          }
          Parse {
            "@sha256:"
            alphasDigits.map {
              Tail(type: .Digest, value: "sha256:" + String($0))
            }
          }
        }
      }
      End()
    }

    let result = try parser.parse(name)

    self.host = String(result.0)
    self.namespace = String(result.1)
    if let tail = result.2 {
      self.reference = tail.value
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
}
