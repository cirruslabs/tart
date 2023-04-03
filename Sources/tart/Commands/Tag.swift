import ArgumentParser
import Foundation

struct Tag: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "tag", abstract: "Tag an OCI VM",
                                                  discussion: """
                                                  Create a tag <target-oci> that refers \
                                                  to the <source-oci> VM.
                                                  """)

  @Argument(help: "Source OCI VM name (should exist).")
  var sourceOCI: String

  @Argument(help: "Target OCI VM name (normally doesn't exist, otherwise will be overwritten).")
  var targetOCI: String

  func run() async throws {
    guard let sourceOCIParsed = try? RemoteName(sourceOCI) else {
      throw RuntimeError.TagFailed("source VM name is not OCI-compliant")
    }

    guard let targetOCIParsed = try? RemoteName(targetOCI) else {
      throw RuntimeError.TagFailed("target VM name is not OCI-compliant")
    }

    // Make sure that the source OCI VM actually exists
    let storage = VMStorageOCI()
    if !storage.exists(sourceOCIParsed) {
      throw RuntimeError.TagFailed("source OCI VM \"\(sourceOCI)\" does not exist")
    }

    try storage.link(from: targetOCIParsed, to: sourceOCIParsed, resolveSymlinks: true)
  }
}
