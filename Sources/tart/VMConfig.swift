import Virtualization

class LessThanMinimalResourcesError: NSObject, LocalizedError {
  var userExplanation: String

  init(_ userExplanation: String) {
    self.userExplanation = userExplanation
  }

  override var description: String {
    get {
      "LessThanMinimalResourcesError: \(userExplanation)"
    }
  }
}

enum CodingKeys: String, CodingKey {
  case version
  case os
  case arch
  case cpuCountMin
  case cpuCount
  case memorySizeMin
  case memorySize
  case macAddress
  case display

  // macOS-specific keys
  case ecid
  case hardwareModel
}

struct VMDisplayConfig: Codable {
  var width: Int = 1024
  var height: Int = 768
}

struct VMConfig: Codable {
  var version: Int = 1
  var os: OS
  var arch: Architecture
  var platform: Platform
  var cpuCountMin: Int
  private(set) var cpuCount: Int
  var memorySizeMin: UInt64
  private(set) var memorySize: UInt64
  var macAddress: VZMACAddress
  var display: VMDisplayConfig = VMDisplayConfig()

  init(
          platform: Platform,
          cpuCountMin: Int,
          memorySizeMin: UInt64,
          macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()
  ) {
    self.os = platform.os()
    self.arch = CurrentArchitecture()
    self.platform = platform
    self.macAddress = macAddress
    self.cpuCountMin = cpuCountMin
    self.memorySizeMin = memorySizeMin
    cpuCount = cpuCountMin
    memorySize = memorySizeMin
  }

  init(fromJSON: Data) throws {
    self = try Config.jsonDecoder().decode(Self.self, from: fromJSON)
  }

  init(fromURL: URL) throws {
    self = try Self(fromJSON: try Data(contentsOf: fromURL))
  }

  func toJSON() throws -> Data {
    try Config.jsonEncoder().encode(self)
  }

  func save(toURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    try encoder.encode(self).write(to: toURL)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    version = try container.decode(Int.self, forKey: .version)
    os = try container.decodeIfPresent(OS.self, forKey: .os) ?? .darwin
    arch = try container.decodeIfPresent(Architecture.self, forKey: .arch) ?? .arm64
    switch os {
    case .darwin:
      platform = try Darwin(from: decoder)
    case .linux:
      if #available(macOS 13, *) {
        platform = try Linux(from: decoder)
      } else {
        throw UnsupportedOSError()
      }
    }
    cpuCountMin = try container.decode(Int.self, forKey: .cpuCountMin)
    cpuCount = try container.decode(Int.self, forKey: .cpuCount)
    memorySizeMin = try container.decode(UInt64.self, forKey: .memorySizeMin)
    memorySize = try container.decode(UInt64.self, forKey: .memorySize)

    let encodedMacAddress = try container.decode(String.self, forKey: .macAddress)
    guard let macAddress = VZMACAddress.init(string: encodedMacAddress) else {
      throw DecodingError.dataCorruptedError(
                forKey: .hardwareModel,
                in: container,
                debugDescription: "failed to initialize VZMacAddress using the provided value")
    }
    self.macAddress = macAddress
    
    display = try container.decodeIfPresent(VMDisplayConfig.self, forKey: .display) ?? VMDisplayConfig()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(version, forKey: .version)
    try container.encode(os, forKey: .os)
    try container.encode(arch, forKey: .arch)
    try platform.encode(to: encoder)
    try container.encode(cpuCountMin, forKey: .cpuCountMin)
    try container.encode(cpuCount, forKey: .cpuCount)
    try container.encode(memorySizeMin, forKey: .memorySizeMin)
    try container.encode(memorySize, forKey: .memorySize)
    try container.encode(macAddress.string, forKey: .macAddress)
    try container.encode(display, forKey: .display)
  }

  mutating func setCPU(cpuCount: Int) throws {
    if cpuCount < cpuCountMin {
      throw LessThanMinimalResourcesError("VM should have \(cpuCountMin) CPU cores"
              + " at minimum (requested \(cpuCount))")
    }

    self.cpuCount = cpuCount
  }

  mutating func setMemory(memorySize: UInt64) throws {
    if memorySize < memorySizeMin {
      throw LessThanMinimalResourcesError("VM should have \(memorySizeMin) bytes"
              + " of memory at minimum (requested \(memorySizeMin))")
    }

    self.memorySize = memorySize
  }
}
