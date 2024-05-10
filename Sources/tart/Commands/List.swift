import ArgumentParser
import Dispatch
import SwiftUI

fileprivate struct VMInfo: Encodable {
  let Source: String
  let Name: String
  let Disk: Int
  let Size: Int
  let Running: Bool
  let State: String
}

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  @Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
  var source: String?

  @Option(help: "Output format: text or json")
  var format: Format = .text

  @Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
  var quiet: Bool = false

  func validate() throws {
    guard let source = source else {
      return
    }

    if !["local", "oci"].contains(source) {
      throw ValidationError("'\(source)' is not a valid <source>")
    }
  }

  func run() async throws {
    var infos: [VMInfo] = []

    if source == nil || source == "local" {
      infos += sortedInfos(try VMStorageLocal().list().map { (name, vmDir) in
        try VMInfo(Source: "local", Name: name, Disk: vmDir.sizeGB(), Size: vmDir.allocatedSizeGB(), Running: vmDir.running(), State: vmDir.state().rawValue)
      })
    }

    if source == nil || source == "oci" {
      infos += sortedInfos(try VMStorageOCI().list().map { (name, vmDir, _) in
        try VMInfo(Source: "OCI", Name: name, Disk: vmDir.sizeGB(), Size: vmDir.allocatedSizeGB(), Running: vmDir.running(), State: vmDir.state().rawValue)
      })
    }

    if (quiet) {
      for info in infos {
        print(info.Name)
      }
    } else {
      print(format.renderList(infos))
    }
  }

  private func sortedInfos(_ infos: [VMInfo]) -> [VMInfo] {
    infos.sorted(by: { left, right in left.Name < right.Name })
  }
}
