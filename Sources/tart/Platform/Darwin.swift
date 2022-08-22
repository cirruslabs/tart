import Virtualization

struct Darwin: Platform {
    var ecid: VZMacMachineIdentifier
    var hardwareModel: VZMacHardwareModel

    init(ecid: VZMacMachineIdentifier, hardwareModel: VZMacHardwareModel) {
        self.ecid = ecid
        self.hardwareModel = hardwareModel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let encodedECID = try container.decode(String.self, forKey: .ecid)
        guard let data = Data.init(base64Encoded: encodedECID) else {
            throw DecodingError.dataCorruptedError(forKey: .ecid,
                    in: container,
                    debugDescription: "failed to initialize Data using the provided value")
        }
        guard let ecid = VZMacMachineIdentifier.init(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(forKey: .ecid,
                    in: container,
                    debugDescription: "failed to initialize VZMacMachineIdentifier using the provided value")
        }

        let encodedHardwareModel = try container.decode(String.self, forKey: .hardwareModel)
        guard let data = Data.init(base64Encoded: encodedHardwareModel) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel, in: container, debugDescription: "")
        }
        guard let hardwareModel = VZMacHardwareModel.init(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel, in: container, debugDescription: "")
        }

        self.ecid = ecid
        self.hardwareModel = hardwareModel
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(ecid.dataRepresentation.base64EncodedString(), forKey: .ecid)
        try container.encode(hardwareModel.dataRepresentation.base64EncodedString(), forKey: .hardwareModel)
    }

    func os() -> OS {
        .darwin
    }

    func bootLoader(nvramURL: URL) throws -> VZBootLoader {
        VZMacOSBootLoader()
    }

    func platform(nvramURL: URL) -> VZPlatformConfiguration {
        let auxStorage = VZMacAuxiliaryStorage(contentsOf: nvramURL)

        let result = VZMacPlatformConfiguration()

        result.machineIdentifier = ecid
        result.auxiliaryStorage = auxStorage
        result.hardwareModel = hardwareModel

        return result
    }

    func graphicsDevice(vmConfig: VMConfig) -> VZGraphicsDeviceConfiguration {
        let result = VZMacGraphicsDeviceConfiguration()

        if let hostMainScreen = NSScreen.main {
            let vmScreenSize = NSSize(width: vmConfig.display.width, height: vmConfig.display.height)
            result.displays = [
                VZMacGraphicsDisplayConfiguration(for: hostMainScreen, sizeInPoints: vmScreenSize)
            ]

            return result
        }

        result.displays = [
            VZMacGraphicsDisplayConfiguration(
                    widthInPixels: vmConfig.display.width,
                    heightInPixels: vmConfig.display.height,
                    // A reasonable guess according to Apple's documentation[1]
                    // [1]: https://developer.apple.com/documentation/coregraphics/1456599-cgdisplayscreensize
                    pixelsPerInch: 72
            )
        ]

        return result
    }
}
