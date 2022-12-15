import ArgumentParser
import Foundation
import Puppy
import Sentry

var puppy = Puppy.default

class LogFormatter: LogFormattable {
  func formatMessage(_ level: LogLevel, message: String, tag: String, function: String, file: String, line: UInt, swiftLogInfo: [String: String], label: String, date: Date, threadID: UInt64) -> String {
    "\(date) \(level) \(message)"
  }
}

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
      IP.self,
      Pull.self,
      Push.self,
      Prune.self,
      Rename.self,
      Stop.self,
      Delete.self,
    ])

  public static func main() async throws {
    // Initialize Sentry
    if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] {
      SentrySDK.start { options in
        options.dsn = dsn
      }
    }
    defer { SentrySDK.flush(timeout: 2.seconds.timeInterval) }

    // Enrich future events with Cirrus CI-specific tags
    if let tags = ProcessInfo.processInfo.environment["CIRRUS_SENTRY_TAGS"] {
      SentrySDK.configureScope { scope in
        for (key, value) in tags.split(separator: ",").compactMap({ parseCirrusSentryTag($0) }) {
          scope.setTag(value: value, key: key)
        }
      }
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

    // Initialize file logger
    let logFileURL = try Config().tartHomeDir.appendingPathComponent("tart.log")
    let fileLogger = try FileLogger("org.cirruslabs.tart", fileURL: logFileURL)
    fileLogger.format = LogFormatter()
    puppy.add(fileLogger)

    // Parse and run command
    do {
      var command = try parseAsRoot()

      // Run garbage-collection before each command (shouldn't take too long)
      try Config().gc()

      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      // Capture the error into Sentry
      SentrySDK.capture(error: error)
      SentrySDK.flush(timeout: 2.seconds.timeInterval)

      exit(withError: error)
    }
  }

  private static func parseCirrusSentryTag(_ tag: String.SubSequence) -> (String, String)? {
    let splits = tag.split(separator: "=", maxSplits: 1)
    if splits.count != 2 {
      return nil
    }

    return (String(splits[0]), String(splits[1]))
  }
}
