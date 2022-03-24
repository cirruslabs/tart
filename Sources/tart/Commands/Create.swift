import ArgumentParser
import Dispatch
import SwiftUI
import Foundation

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(help: ArgumentHelp("Path to the IPSW file (or \"latest\") to fetch the latest appropriate IPSW", valueName: "path")) var fromIPSW: String?

  func validate() throws {
    if fromIPSW == nil {
      throw ValidationError("Please specify a --from-ipsw option!")
    }
  }

  func run() async throws {
    do {
      let vmDir = try VMStorage().create(name)

      if fromIPSW! == "latest" {
        _ = try await VM(vmDir: vmDir, ipswURL: nil)
      } else {
        _ = try await VM(vmDir: vmDir, ipswURL: URL(fileURLWithPath: fromIPSW!))
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }
}
