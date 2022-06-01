import ArgumentParser
import Dispatch
import SwiftUI
import Foundation

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(help: ArgumentHelp("Path to the IPSW file (or \"latest\") to fetch the latest appropriate IPSW", valueName: "path")) 
  var fromIPSW: String?

  @Option(help: ArgumentHelp("Disk size in Gb")) 
  var diskSize: UInt8 = 50

  func validate() throws {
    if fromIPSW == nil {
      throw ValidationError("Please specify a --from-ipsw option!")
    }
  }

  func run() async throws {
    do {
      let tmpVMDir = try VMDirectory.temporary()
      try await withTaskCancellationHandler(operation: {
        if fromIPSW! == "latest" {
          _ = try await VM(vmDir: tmpVMDir, ipswURL: nil, diskSizeGB: diskSize)
        } else {
          _ = try await VM(vmDir: tmpVMDir, ipswURL: URL(fileURLWithPath: fromIPSW!), diskSizeGB: diskSize)
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
