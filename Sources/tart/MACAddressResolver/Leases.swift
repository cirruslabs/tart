import Foundation
import Network

enum LeasesError: Error {
  case UnexpectedFormat(name: String = "unexpected DHCPD leases file format", message: String, line: Int)
  case Truncated(name: String = "truncated DHCPD leases file")

  var description: String {
    switch self {

    case .UnexpectedFormat(name: let name, message: let message, line: let line):
      return "\(name) on line \(line): \(message)"
    case .Truncated(name: let name):
      return "\(name)"
    }
  }
}

class Leases {
  private let leases: [MACAddress : Lease]

  convenience init() throws {
    try self.init(URL(fileURLWithPath: "/var/db/dhcpd_leases"))
  }

  convenience init(_ fromURL: URL) throws {
    let fileContents = try String(contentsOf: fromURL, encoding: .utf8)

    try self.init(fileContents)
  }

  init(_ fromString: String) throws {
    var leases: [MACAddress : Lease] = Dictionary()

    for lease in try Self.retrieveRawLeases(fromString).compactMap({ Lease(fromRawLease: $0) }) {
      leases[lease.mac] = lease
    }

    self.leases = leases
  }

  /// Parse leases from the host cache similarly to the PLCache_read() function found in Apple's Open Source releases.
  ///
  /// [1]: https://github.com/apple-opensource/bootp/blob/master/bootplib/NICache.c#L285-L391
  private static func retrieveRawLeases(_ dhcpdLeasesContents: String) throws -> [[String : String]] {
    var rawLeases: [[String : String]] = Array()

    enum State {
      case Nowhere
      case Start
      case Body
      case End
    }
    var state = State.Nowhere

    var currentRawLease: [String : String] = Dictionary()

    for (lineNumber, line) in dhcpdLeasesContents.split(separator: "\n").enumerated().map({ ($0 + 1, $1) }) {
      if line == "{" {
        // Handle lease block start
        if state != .Nowhere && state != .End {
          throw LeasesError.UnexpectedFormat(message: "unexpected lease block start ({)", line: lineNumber)
        }

        state = .Start
      } else if line == "}" {
        // Handle lease block end
        if state != .Body {
          throw LeasesError.UnexpectedFormat(message: "unexpected lease block end (})", line: lineNumber)
        }

        rawLeases.append(currentRawLease)
        currentRawLease = Dictionary()

        state = .End
      } else {
        // Handle lease block contents
        let lineWithoutTabs = String(line.drop { $0 == " " || $0 == "\t"})

        if lineWithoutTabs.isEmpty {
          continue
        }

        let splits = lineWithoutTabs.split(separator: "=", maxSplits: 1)
        if splits.count != 2 {
          throw LeasesError.UnexpectedFormat(message: "key-value pair with only a key", line: lineNumber)
        }
        let (key, value) = (String(splits[0]), String(splits[1]))

        currentRawLease[key] = value

        state = .Body
      }
    }

    if state == .Start || state == .Body {
      throw LeasesError.Truncated()
    }

    return rawLeases
  }

  func resolveMACAddress(macAddress: MACAddress) throws -> IPv4Address? {
    leases[macAddress]?.ip
  }
}
