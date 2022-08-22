import Virtualization

protocol Platform: Codable {
    func os() -> OS
    func bootLoader(nvramURL: URL) throws -> VZBootLoader
    func platform(nvramURL: URL) -> VZPlatformConfiguration
    func graphicsDevice(vmConfig: VMConfig) -> VZGraphicsDeviceConfiguration
}
