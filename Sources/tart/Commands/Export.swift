import ArgumentParser

struct Export: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Export VM to a file")

  @Argument(help: "Source VM name.")
  var name: String

  @Argument(help: "Path to the destination file.")
  var path: String

  func run() async throws {
    print("exporting...")
    try VMStorageHelper.open(name).exportToArchive(path: path)
  }
}
