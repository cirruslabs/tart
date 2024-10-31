import Virtualization

@available(macOS 13, *)
struct Linux: Platform {
  func os() -> OS {
    .linux
  }

  func bootLoader(nvramURL: URL) throws -> VZBootLoader {
    let result = VZEFIBootLoader()

    result.variableStore = VZEFIVariableStore(url: nvramURL)

    return result
  }

  func platform(nvramURL: URL) throws -> VZPlatformConfiguration {
    let result: VZGenericPlatformConfiguration = VZGenericPlatformConfiguration()

    if #available(macOS 15.0, *) {
      if VZGenericPlatformConfiguration.isNestedVirtualizationSupported {
        result.isNestedVirtualizationEnabled = true
      }
    }

    return result
  }

  func graphicsDevice(vmConfig: VMConfig) -> VZGraphicsDeviceConfiguration {
    let result = VZVirtioGraphicsDeviceConfiguration()

    result.scanouts = [
      VZVirtioGraphicsScanoutConfiguration(
        widthInPixels: vmConfig.display.width,
        heightInPixels: vmConfig.display.height
      )
    ]

    return result
  }

  func keyboards() -> [VZKeyboardConfiguration] {
    [VZUSBKeyboardConfiguration()]
  }

  func pointingDevices() -> [VZPointingDeviceConfiguration] {
    [VZUSBScreenCoordinatePointingDeviceConfiguration()]
  }
}
