import Virtualization

class LessThanMinimalResourcesError: NSObject, LocalizedError {
  var userExplanation: String

  init(_ userExplanation: String) {
    self.userExplanation = userExplanation
  }

  override var description: String {
    get {
      return "LessThanMinimalResourcesError: \(self.userExplanation)"
    }
  }
}

enum CodingKeys: String, CodingKey {
  case version
  case ecid
  case hardwareModel
  case cpuCountMin
  case cpuCount
  case memorySizeMin
  case memorySize
  case macAddress
}

struct VMConfig: Encodable, Decodable {
  var version: Int = 1
  var ecid: VZMacMachineIdentifier
  var hardwareModel: VZMacHardwareModel
  var cpuCountMin: Int
  private(set) var cpuCount: Int
  var memorySizeMin: UInt64
  private(set) var memorySize: UInt64
  var macAddress: VZMACAddress

  init(
    ecid: VZMacMachineIdentifier = VZMacMachineIdentifier(),
    hardwareModel: VZMacHardwareModel,
    cpuCountMin: Int,
    memorySizeMin: UInt64,
    macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()
  ) {
    self.ecid = ecid
    self.hardwareModel = hardwareModel
    self.cpuCountMin = cpuCountMin
    self.cpuCount = cpuCountMin
    self.memorySizeMin = memorySizeMin
    self.memorySize = memorySizeMin
    self.macAddress = macAddress
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

    // Migrate to newer version
    if version == 0 {
      self.cpuCountMin = self.cpuCount
      self.memorySizeMin = self.memorySize
      self.version = 1
    } else {
      self.cpuCountMin = try container.decode(Int.self, forKey: .cpuCountMin)
      self.memorySizeMin = try container.decode(UInt64.self, forKey: .memorySizeMin)
    }

    let encodedMacAddress = try container.decode(String.self, forKey: .macAddress)
    guard let macAddress = VZMACAddress.init(string: encodedMacAddress) else {
      throw DecodingError.dataCorruptedError(
                forKey: .hardwareModel,
                in: container,
                debugDescription: "failed to initialize VZMacAddress using the provided value")
    }
    self.macAddress = macAddress
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(self.version, forKey: .version)
    try container.encode(self.ecid.dataRepresentation.base64EncodedString(), forKey: .ecid)
    try container.encode(self.hardwareModel.dataRepresentation.base64EncodedString(), forKey: .hardwareModel)
    try container.encode(self.cpuCountMin, forKey: .cpuCountMin)
    try container.encode(self.cpuCount, forKey: .cpuCount)
    try container.encode(self.memorySizeMin, forKey: .memorySizeMin)
    try container.encode(self.memorySize, forKey: .memorySize)
    try container.encode(self.macAddress.string, forKey: .macAddress)
  }

  mutating func setCPU(cpuCount: Int) throws {
    if cpuCount < self.cpuCountMin {
      throw LessThanMinimalResourcesError("VM should have \(self.cpuCountMin) CPU cores"
              + " at minimum (requested \(cpuCount))")
    }

    self.cpuCount = cpuCount
  }

  mutating func setMemory(memorySize: UInt64) throws {
    if memorySize < self.memorySizeMin {
      throw LessThanMinimalResourcesError("VM should have \(self.memorySizeMin) bytes"
              + " of memory at minimum (requested \(self.memorySizeMin))")
    }

    self.memorySize = memorySize
  }
}
