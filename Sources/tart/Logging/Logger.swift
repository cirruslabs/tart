import Foundation

public protocol Logger {
    func appendNewLine(_ line: String) -> Void
    func updateLastLine(_ line: String) -> Void
}

var defaultLogger: Logger = {
    if ProcessInfo.processInfo.environment["CI"] != nil {
        return SimpleConsoleLogger()
    } else {
        return InteractiveConsoleLogger()
    }
}()

public class InteractiveConsoleLogger: Logger {
    private let eraseLine = "\\x1B[K" // clear entire line

    public init() {

    }

    public func appendNewLine(_ line: String) {
        print(line, terminator: "\n")
    }

    public func updateLastLine(_ line: String) {
        print(eraseLine) // current empty line
        print(eraseLine) // previous line that we want to update
        print(line, terminator: "\n")
    }
}

public class SimpleConsoleLogger: Logger {
    public init() {

    }

    public func appendNewLine(_ line: String) {
        print(line, terminator: "\n")
    }

    public func updateLastLine(_ line: String) {
        print(line, terminator: "\n")
    }
}
