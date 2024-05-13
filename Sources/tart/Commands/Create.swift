import ArgumentParser
import Dispatch
import Foundation
import SwiftUI
import Virtualization

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(help: ArgumentHelp("create a macOS VM using path to the IPSW file or URL (or \"latest\", to fetch the latest supported IPSW automatically)", valueName: "path"))
  var fromIPSW: String?

  @Flag(help: "create a Linux VM")
  var linux: Bool = false

  @Option(help: ArgumentHelp("Disk size in GB"))
  var diskSize: UInt16 = 50

  func validate() throws {
    if fromIPSW == nil && !linux {
      throw ValidationError("Please specify either a --from-ipsw or --linux option!")
    }
    #if arch(x86_64)
      if fromIPSW != nil {
        throw ValidationError("Only Linux VMs are supported on Intel!")
      }
    #endif
  }

  func run() async throws {
    let tmpVMDir = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(operation: {
      #if arch(arm64)
        if let fromIPSW = fromIPSW {
          let ipswURL: URL

          if fromIPSW == "latest" {
            defaultLogger.appendNewLine("Looking up the latest supported IPSW...")

            let image = try await withCheckedThrowingContinuation { continuation in
              VZMacOSRestoreImage.fetchLatestSupported() { result in
                continuation.resume(with: result)
              }
            }

            ipswURL = image.url
          } else if fromIPSW.starts(with: "http://") || fromIPSW.starts(with: "https://") {
            ipswURL = URL(string: fromIPSW)!
          } else {
            ipswURL = URL(fileURLWithPath: NSString(string: fromIPSW).expandingTildeInPath)
          }

          _ = try await VM(vmDir: tmpVMDir, ipswURL: ipswURL, diskSizeGB: diskSize)
        }
      #endif

      if linux {
        _ = try await VM.linux(vmDir: tmpVMDir, diskSizeGB: diskSize)
      }

      try VMStorageLocal().move(name, from: tmpVMDir)
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}
