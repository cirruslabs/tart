import ArgumentParser

struct Root: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "tart",
        subcommands: [Create.self, Clone.self, Run.self, List.self, IP.self, Delete.self])
}
