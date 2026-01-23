import ArgumentParser
import Darwin
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tart",
    version: CI.version,
    subcommands: [
      Create.self,
      Clone.self,
      Run.self,
      Set.self,
      Get.self,
      List.self,
      Login.self,
      Logout.self,
      IP.self,
      Exec.self,
      Pull.self,
      Push.self,
      Import.self,
      Export.self,
      Prune.self,
      Rename.self,
      Stop.self,
      Delete.self,
      FQN.self,
    ])

  public static func main() async throws {
    // Add commands that are only available on specific macOS versions
    if #available(macOS 14, *) {
      configuration.subcommands.append(Suspend.self)
    }

    // Ensure the default SIGINT handled is disabled,
    // otherwise there's a race between two handlers
    signal(SIGINT, SIG_IGN);
    // Handle cancellation by Ctrl+C ourselves
    let task = withUnsafeCurrentTask { $0 }!
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // Set line-buffered output for stdout
    setlinebuf(stdout)

    defer { OTel.shared.flush() }

    do {
      // Parse command
      var command = try parseAsRoot()

      // Create a root span for the command we're about to run
      let span = OTel.shared.tracer.spanBuilder(spanName: type(of: command)._commandName).startSpan()
      defer { span.end() }
      OpenTelemetry.instance.contextProvider.setActiveSpan(span)

      // Enrich root command span with command's arguments
      let commandLineArguments = ProcessInfo.processInfo.arguments.map { argument in
        AttributeValue.string(argument)
      }
      span.setAttribute(key: "Command-line arguments", value: .array(AttributeArray(values: commandLineArguments)))

      // Enrich root command span with Cirrus CI-specific tags
      if let tags = ProcessInfo.processInfo.environment["CIRRUS_SENTRY_TAGS"] {
        for (key, value) in tags.split(separator: ",").compactMap(splitEnvironmentVariable) {
          span.setAttribute(key: key, value: .string(value))
        }
      }

      // Run garbage-collection before each command (shouldn't take too long)
      if type(of: command) != type(of: Pull()) && type(of: command) != type(of: Clone()){
        do {
          try Config().gc()
        } catch {
          fputs("Failed to perform garbage collection: \(error)\n", stderr)
        }
      }

      // Run command
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      // Not an error, just a custom exit code from "tart exec"
      if let execCustomExitCodeError = error as? ExecCustomExitCodeError {
        OTel.shared.flush()
        Foundation.exit(execCustomExitCodeError.exitCode)
      }

      // Capture the error into OpenTelemetry
      OpenTelemetry.instance.contextProvider.activeSpan?.recordException(error)

      // Handle a non-ArgumentParser's exception that requires a specific exit code to be set
      if let errorWithExitCode = error as? HasExitCode {
        fputs("\(error)\n", stderr)

        OTel.shared.flush()
        Foundation.exit(errorWithExitCode.exitCode)
      }

      // Handle any other exception, including ArgumentParser's ones
      exit(withError: error)
    }
  }

  private static func splitEnvironmentVariable(_ tag: String.SubSequence) -> (String, String)? {
    let splits = tag.split(separator: "=", maxSplits: 1)
    if splits.count != 2 {
      return nil
    }

    return (String(splits[0]), String(splits[1]))
  }
}
