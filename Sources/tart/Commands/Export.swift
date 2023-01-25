import ArgumentParser

struct Export: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Export VM to a file")

  @Argument(help: "Source VM name.")
  var name: String

  @Argument(help: "Path to the destination file.")
  var path: String

  func run() async throws {
    let vm = try VMStorageHelper.open(name)
    let archive = try ArchiveWriter(path)

    _ = try await vm.pushToRegistry(registry: archive, references: [""], chunkSizeMb: 0)
  }
}
