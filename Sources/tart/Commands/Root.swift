import ArgumentParser

struct Root: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "tart",
        subcommands: [Create.self, Run.self, List.self, Delete.self])
}
