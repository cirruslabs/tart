import ArgumentParser
import Dispatch
import SwiftUI
import Foundation

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(help: ArgumentHelp("create a macOS VM using path to the IPSW file (or \"latest\") to fetch the latest appropriate IPSW", valueName: "path"))
  var fromIPSW: String?

  @Flag(help: "create a Linux VM")
  var linux: Bool = false

  @Option(help: ArgumentHelp("Disk size in Gb")) 
  var diskSize: UInt16 = 50

  func validate() throws {
    if fromIPSW == nil && !linux {
      throw ValidationError("Please specify either a --from-ipsw or --linux option!")
    }
  }

  func run() async throws {
    do {
      let tmpVMDir = try VMDirectory.temporary()
      try await withTaskCancellationHandler(operation: {
        if let fromIPSW = fromIPSW {
          if fromIPSW == "latest" {
            _ = try await VM(vmDir: tmpVMDir, ipswURL: nil, diskSizeGB: diskSize)
          } else {
            _ = try await VM(vmDir: tmpVMDir, ipswURL: URL(fileURLWithPath: fromIPSW), diskSizeGB: diskSize)
          }
        }

        if linux {
          if #available(macOS 13, *) {
            _ = try await VM.linux(vmDir: tmpVMDir, diskSizeGB: diskSize)
          } else {
            throw UnsupportedOSError("Linux VMs", "are")
          }
        }

        try VMStorageLocal().move(name, from: tmpVMDir)
      }, onCancel: {
        try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
      })

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
