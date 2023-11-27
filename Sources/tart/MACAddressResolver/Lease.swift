import Foundation
import Network
import SwiftRadix

struct Lease {
  var mac: MACAddress
  var ip: IPv4Address
  var expiresAt: Date

  init?(fromRawLease: [String : String]) {
    // Retrieve the required fields
    guard let hwAddress = fromRawLease["hw_address"] else { return nil }
    guard let ipAddress = fromRawLease["ip_address"] else { return nil }
    guard let lease = fromRawLease["lease"] else { return nil }

    // Parse MAC address
    let hwAddressSplits = hwAddress.split(separator: ",")
    if hwAddressSplits.count != 2 {
      return nil
    }
    if let hwAddressProto = Int(hwAddressSplits[0]), hwAddressProto != ARPHRD_ETHER {
      return nil
    }
    guard let mac = MACAddress(fromString: String(hwAddressSplits[1])) else {
      return nil
    }

    // Parse IP address
    guard let ip = IPv4Address(ipAddress) else {
      return nil
    }

    // Parse expiration timestamp
    guard let leaseTimestamp = lease.hex?.value else {
      return nil
    }

    self.ip = ip
    self.mac = mac
    self.expiresAt = Date(timeIntervalSince1970: TimeInterval(leaseTimestamp))
  }
}
