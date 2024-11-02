import Foundation
import Virtualization

enum Architecture: String, Codable {
  case arm64
  case amd64
}

func CurrentArchitecture() -> Architecture {
  #if arch(arm64)
    return .arm64
  #elseif arch(x86_64)
    return .amd64
  #endif
}

func isNestedVirtualizationSupported() -> Bool {
  if #available(macOS 15.0, *) {
    return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
  }

  return false
}
