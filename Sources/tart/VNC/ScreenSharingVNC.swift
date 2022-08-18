import Foundation
import Dynamic
import Virtualization

class ScreenSharingVNC: VNC {
  let vmConfig: VMConfig

  init(vmConfig: VMConfig) {
    self.vmConfig = vmConfig
  }

  func waitForURL() async throws -> URL {
    let vmMACAddress = MACAddress(fromString: vmConfig.macAddress.string)!
    let ip = try await IP.resolveIP(vmMACAddress, secondsToWait: 60)

    if let ip = ip {
      return URL(string: "vnc://\(ip)")!
    }

    throw IPNotFound()
  }

  func stop() throws {
    // nothing to do
  }
}
