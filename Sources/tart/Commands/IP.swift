import ArgumentParser
import Foundation
import Network
import SystemConfiguration
import Sentry

enum IPResolutionStrategy: String, ExpressibleByArgument, CaseIterable {
  case dhcp, arp

  private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}
}

struct IP: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Get VM's IP address")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Option(help: "Number of seconds to wait for a potential VM booting")
  var wait: UInt16 = 0

  @Option(help: ArgumentHelp("Strategy for resolving IP address: dhcp or arp",
                             discussion: """
                             By default, Tart is looking up and parsing DHCP lease file to determine the IP of the VM.\n
                             This method is fast and the most reliable but only returns local IP adresses.\n
                             Alternatively, Tart can call external `arp` executable and parse it's output.\n
                             In case of enabled Bridged Networking this method will return VM's IP address on the network interface used for Bridged Networking.\n
                             Note that `arp` strategy won't work for VMs using `--net-softnet`.
                             """))
  var resolver: IPResolutionStrategy = .dhcp

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
    let vmMACAddress = MACAddress(fromString: vmConfig.macAddress.string)!

    guard let ip = try await IP.resolveIP(vmMACAddress, resolutionStrategy: resolver, secondsToWait: wait) else {
      var message = "no IP address found"

      if try !vmDir.running() {
        message += ", is your VM running?"
      }

      if (vmConfig.os == .linux && resolver == .arp) {
        message += " (not all Linux distributions are compatible with the ARP resolver)"
      }

      throw RuntimeError.NoIPAddressFound(message)
    }

    print(ip)
  }

  static public func resolveIP(_ vmMACAddress: MACAddress, resolutionStrategy: IPResolutionStrategy = .dhcp, secondsToWait: UInt16 = 0) async throws -> IPv4Address? {
    let waitUntil = Calendar.current.date(byAdding: .second, value: Int(secondsToWait), to: Date.now)!

    repeat {
      switch resolutionStrategy {
      case .arp:
        if let ip = try ARPCache().ResolveMACAddress(macAddress: vmMACAddress) {
          return ip
        }
      case .dhcp:
        if let leases = try Leases(), let ip = leases.ResolveMACAddress(macAddress: vmMACAddress) {
          return ip
        }
      }

      // wait a second
      try await Task.sleep(nanoseconds: 1_000_000_000)
    } while Date.now < waitUntil

    return nil
  }
}
