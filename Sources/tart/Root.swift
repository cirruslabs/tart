import ArgumentParser

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tart",
    subcommands: [Create.self, Clone.self, Run.self, List.self, IP.self, Delete.self])
}
