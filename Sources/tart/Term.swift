import Foundation
import System

struct State {
  fileprivate let termios: termios
}

class Term {
  static func IsTerminal() -> Bool {
    var termios = termios()

    return tcgetattr(FileHandle.standardInput.fileDescriptor, &termios) != -1
  }

  static func MakeRaw() throws -> State {
    var termiosOrig = termios()

    var ret = tcgetattr(FileHandle.standardInput.fileDescriptor, &termiosOrig)
    if ret == -1 {
      let details = Errno(rawValue: CInt(errno))

      throw RuntimeError.TerminalOperationFailed("failed to retrieve terminal parameters: \(details)")
    }

    var termiosRaw = termiosOrig
    cfmakeraw(&termiosRaw)

    ret = tcsetattr(FileHandle.standardInput.fileDescriptor, TCSANOW, &termiosRaw)
    if ret == -1 {
      let details = Errno(rawValue: CInt(errno))

      throw RuntimeError.TerminalOperationFailed("failed to set terminal parameters: \(details)")
    }

    return State(termios: termiosOrig)
  }

  static func Restore(_ state: State) throws {
    var termios = state.termios

    let ret = tcsetattr(FileHandle.standardInput.fileDescriptor, TCSANOW, &termios)
    if ret == -1 {
      let details = Errno(rawValue: CInt(errno))

      throw RuntimeError.TerminalOperationFailed("failed to set terminal parameters: \(details)")
    }
  }

  static func GetSize() throws -> (width: UInt16, height: UInt16) {
    var winsize = winsize()

    guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) != -1 else {
      let details = Errno(rawValue: CInt(errno))

      throw RuntimeError.TerminalOperationFailed("failed to get terminal size: \(details)")
    }

    return (width: winsize.ws_col, height: winsize.ws_row)
  }
}
