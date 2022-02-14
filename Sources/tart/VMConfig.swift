import Virtualization

enum CodingKeys: String, CodingKey {
    case version
    case ecid
    case hardwareModel
    case cpuCount
    case memorySize
}

struct VMConfig: Encodable, Decodable {
    var version: Int = 0
    var ecid: VZMacMachineIdentifier
    var hardwareModel: VZMacHardwareModel
    var cpuCount: Int
    var memorySize: UInt64
    
    init(ecid: VZMacMachineIdentifier = VZMacMachineIdentifier(), hardwareModel: VZMacHardwareModel, cpuCount: Int, memorySize: UInt64) {
        self.ecid = ecid
        self.hardwareModel = hardwareModel
        self.cpuCount = cpuCount
        self.memorySize = memorySize
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
        
        self.cpuCount = try container.decode(Int.self, forKey: .cpuCount)
        
        self.memorySize = try container.decode(UInt64.self, forKey: .memorySize)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.version, forKey: .version)
        try container.encode(self.ecid.dataRepresentation.base64EncodedString(), forKey: .ecid)
        try container.encode(self.hardwareModel.dataRepresentation.base64EncodedString(), forKey: .hardwareModel)
        try container.encode(self.cpuCount, forKey: .cpuCount)
        try container.encode(self.memorySize, forKey: .memorySize)
    }
}
