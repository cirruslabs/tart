import Foundation
import IOKit

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
    let deviceService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    defer { IOObjectRelease(deviceService) }

    if let modelProperty = IORegistryEntryCreateCFProperty(deviceService, "model" as CFString, kCFAllocatorDefault, 0),
       let modelData = modelProperty.takeRetainedValue() as? Data {
      return String(cString: [UInt8](modelData))
    }

    return "unknown"
  }
}
