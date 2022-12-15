import ArgumentParser
import Foundation
import Network
import SystemConfiguration
import Sentry

struct IP: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Get VM's IP address")

  @Argument(help: "VM name")
  var name: String

  @Option(help: "Number of seconds to wait for a potential VM booting")
  var wait: UInt16 = 0

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
    let vmMACAddress = MACAddress(fromString: vmConfig.macAddress.string)!

    guard let ipViaDHCP = try await IP.resolveIP(vmMACAddress, secondsToWait: wait) else {
      throw RuntimeError("no IP address found, is your VM running?")
    }

    let arpCache = try ARPCache()

    if let ipViaARP = try arpCache.ResolveMACAddress(macAddress: vmMACAddress), ipViaARP != ipViaDHCP {
      // Capture the warning into Sentry
      SentrySDK.capture(message: "DHCP lease and ARP cache entries for a single MAC address differ") { scope in
        scope.setLevel(.warning)

        scope.setContext(value: [
          "MAC address": vmMACAddress,
          "IP via ARP": ipViaARP,
          "IP via DHCP": ipViaDHCP,
        ], key: "Address conflict details")

        scope.add(Attachment(path: "/var/db/dhcpd_leases", filename: "dhcpd_leases.txt", contentType: "text/plain"))
        scope.add(Attachment(data: arpCache.arpCommandOutput, filename: "arp-an-output.txt", contentType: "text/plain"))
      }

      fputs("WARNING: DHCP lease and ARP cache entries for MAC address \(vmMACAddress) differ: "
        + "got \(ipViaDHCP) and \(ipViaARP) respectively, consider reporting this case to"
        + " https://github.com/cirruslabs/tart/issues/172\n", stderr)
    }

    print(ipViaDHCP)
  }

  static public func resolveIP(_ vmMACAddress: MACAddress, secondsToWait: UInt16) async throws -> IPv4Address? {
    let waitUntil = Calendar.current.date(byAdding: .second, value: Int(secondsToWait), to: Date.now)!

    repeat {
      if let leases = try Leases(), let ip = try leases.resolveMACAddress(macAddress: vmMACAddress) {
        return ip
      }

      // wait a second
      try await Task.sleep(nanoseconds: 1_000_000_000)
    } while Date.now < waitUntil

    return nil
  }
}
