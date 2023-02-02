import ArgumentParser
import Dispatch
import SwiftUI

fileprivate struct VMInfo: Encodable {
  let Source: String
  let Name: String
}

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  @Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
  var source: String?

  @Flag(help: "Output format")
  var format: Format = .table

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
        VMInfo(Source: "local", Name: name)
      })
    }

    if source == nil || source == "oci" {
      infos += sortedInfos(try VMStorageOCI().list().map { (name, vmDir, _) in
        VMInfo(Source: "oci", Name: name)
      })
    }
    print(format.renderList(data: infos))
  }

  private func sortedInfos(_ infos: [VMInfo]) -> [VMInfo] {
    infos.sorted(by: { left, right in left.Name < right.Name })
  }
}
