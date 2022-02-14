import Virtualization

enum CodingKeys: String, CodingKey {
    case version
    case ecid
    case hardwareModel
    case cpuCountMin
    case memorySizeMin
}

struct VMConfig: Encodable, Decodable {
    var version: Int = 0
    var ecid: VZMacMachineIdentifier
    var hardwareModel: VZMacHardwareModel
    var cpuCountMin: Int
    var memorySizeMin: UInt64
    
    init(ecid: VZMacMachineIdentifier = VZMacMachineIdentifier(), hardwareModel: VZMacHardwareModel, cpuCountMin: Int, memorySizeMin: UInt64) {
        self.ecid = ecid
        self.hardwareModel = hardwareModel
        self.cpuCountMin = cpuCountMin
        self.memorySizeMin = memorySizeMin
    }
    
    init(fromURL: URL) throws {
        let jsonConfigData = try FileHandle.init(forReadingFrom: fromURL).readToEnd()!
        self = try JSONDecoder().decode(VMConfig.self, from: jsonConfigData)
    }
    
    func save(toURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(self).write(to: toURL)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.version = try container.decode(Int.self, forKey: .version)
        
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
        self.ecid = ecid
        
        let encodedHardwareModel = try container.decode(String.self, forKey: .hardwareModel)
        guard let data = Data.init(base64Encoded: encodedHardwareModel) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel, in: container, debugDescription: "")
        }
        guard let hardwareModel = VZMacHardwareModel.init(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel, in: container, debugDescription: "")
        }
        self.hardwareModel = hardwareModel
        
        self.cpuCountMin = try container.decode(Int.self, forKey: .cpuCountMin)
        
        self.memorySizeMin = try container.decode(UInt64.self, forKey: .memorySizeMin)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.version, forKey: .version)
        try container.encode(self.ecid.dataRepresentation.base64EncodedString(), forKey: .ecid)
        try container.encode(self.hardwareModel.dataRepresentation.base64EncodedString(), forKey: .hardwareModel)
        try container.encode(self.cpuCountMin, forKey: .cpuCountMin)
        try container.encode(self.memorySizeMin, forKey: .memorySizeMin)
    }
}
