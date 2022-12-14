import ArgumentParser
import Foundation
import Network
import SystemConfiguration

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
      print("no IP address found, is your VM running?")

      throw ExitCode.failure
    }

    if let ipViaARP = try ARPCache.ResolveMACAddress(macAddress: vmMACAddress), ipViaARP != ipViaDHCP {
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
