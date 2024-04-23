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

package struct VMDisplayConfig: Codable {
  package var width: Int = 1024
  package var height: Int = 768

  package init(width: Int = 1024, height: Int = 768) {
    self.width = width
    self.height = height
  }
}

extension VMDisplayConfig: CustomStringConvertible {
  package var description: String {
    "\(width)x\(height)"
  }
}

package struct VMConfig: Codable {
  package var version: Int = 1
  package var os: OS
  package var arch: Architecture
  package var platform: Platform
  package var cpuCountMin: Int
  package private(set) var cpuCount: Int
  package var memorySizeMin: UInt64
  package private(set) var memorySize: UInt64
  package var macAddress: VZMACAddress
  package var display: VMDisplayConfig = VMDisplayConfig()

  package init(
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

  package init(fromJSON: Data) throws {
    self = try jsonDecoder().decode(Self.self, from: fromJSON)
  }

  package init(fromURL: URL) throws {
    self = try Self(fromJSON: try Data(contentsOf: fromURL))
  }

  package func toJSON() throws -> Data {
    try jsonEncoder().encode(self)
  }

  package func save(toURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    try encoder.encode(self).write(to: toURL)
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    version = try container.decode(Int.self, forKey: .version)
    os = try container.decodeIfPresent(OS.self, forKey: .os) ?? .darwin
    arch = try container.decodeIfPresent(Architecture.self, forKey: .arch) ?? .arm64
    switch os {
    case .darwin:
      #if arch(arm64)
        platform = try Darwin(from: decoder)
      #else
        throw DecodingError.dataCorruptedError(
          forKey: .os,
          in: container,
          debugDescription: "Darwin VMs are only supported on Apple Silicon hosts")
      #endif
    case .linux:
      platform = try Linux(from: decoder)
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

  package func encode(to encoder: Encoder) throws {
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

  package mutating func setCPU(cpuCount: Int) throws {
    if os == .darwin && cpuCount < cpuCountMin {
      throw LessThanMinimalResourcesError("VM should have \(cpuCountMin) CPU cores"
        + " at minimum (requested \(cpuCount))")
    }

    if cpuCount < VZVirtualMachineConfiguration.minimumAllowedCPUCount {
      throw LessThanMinimalResourcesError("VM should have \(VZVirtualMachineConfiguration.minimumAllowedCPUCount) CPU cores"
        + " at minimum (requested \(cpuCount))")
    }

    self.cpuCount = cpuCount
  }

  package mutating func setMemory(memorySize: UInt64) throws {
    if os == .darwin && memorySize < memorySizeMin {
      throw LessThanMinimalResourcesError("VM should have \(memorySizeMin) bytes"
        + " of memory at minimum (requested \(memorySize))")
    }

    if memorySize < VZVirtualMachineConfiguration.minimumAllowedMemorySize {
      throw LessThanMinimalResourcesError("VM should have \(VZVirtualMachineConfiguration.minimumAllowedMemorySize) bytes"
        + " of memory at minimum (requested \(memorySize))")
    }

    self.memorySize = memorySize
  }
}
