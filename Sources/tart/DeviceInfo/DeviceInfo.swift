import Foundation
import Sysctl

class DeviceInfo {
  private static var osMemoized: String? = nil
  private static var modelMemoized: String? = nil

  static var os: String {
    if let os = osMemoized {
      return os
    }

    osMemoized = getOS()

    return osMemoized!
  }

  static var model: String {
    if let model = modelMemoized {
      return model
    }

    modelMemoized = getModel()

    return modelMemoized!
  }

  private static func getOS() -> String {
    let osVersion = ProcessInfo.processInfo.operatingSystemVersion

    return "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
  }

  private static func getModel() -> String {
    return SystemControl().hardware.model
  }
}
