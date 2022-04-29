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
    do {
      let vmDir = try VMStorageLocal().open(name)
      let vmConfig = try VMConfig.init(fromURL: vmDir.configURL)

      guard let ip = try await resolveIP(vmConfig, secondsToWait: wait) else {
        print("no IP address found, is your VM running?")

        Foundation.exit(1)
      }

      print(ip)

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }

  private func resolveIP(_ config: VMConfig, secondsToWait: UInt16) async throws -> IPv4Address? {
    let waitUntil = Calendar.current.date(byAdding: .second, value: Int(secondsToWait), to: Date.now)!
    let vmMacAddress = MACAddress(fromString: config.macAddress.string)!

    repeat {
      if let ip = try ARPCache.ResolveMACAddress(macAddress: vmMacAddress) {
        return ip
      }

      try await Task.sleep(nanoseconds: 1_000_000)
    } while Date.now < waitUntil

    return nil
  }
}
