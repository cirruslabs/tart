import ArgumentParser

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tart",
    subcommands: [
      Create.self,
      Clone.self,
      Run.self,
      Set.self,
      List.self,
      Login.self,
      IP.self,
      Pull.self,
      Push.self,
      Delete.self,
    ])
}
