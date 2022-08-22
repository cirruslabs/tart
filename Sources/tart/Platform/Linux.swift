import Virtualization

struct Linux: Platform {
    func os() -> OS {
        .linux
    }

    func bootLoader(nvramURL: URL) throws -> VZBootLoader {
        let result = VZEFIBootLoader()

        result.variableStore = VZEFIVariableStore(url: nvramURL)

        return result
    }

    func platform(nvramURL: URL) -> VZPlatformConfiguration {
        VZGenericPlatformConfiguration()
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
}
