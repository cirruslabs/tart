import Foundation
import System

enum FileLockError: Error, Equatable {
  case Failed(_ message: String)
  case AlreadyLocked
}

class FileLock {
  let url: URL
  let fd: Int32

  init(lockURL: URL) throws {
    url = lockURL
    fd = open(lockURL.path, 0)
  }

  deinit {
    close(fd)
  }

  func trylock() throws -> Bool {
    try flockWrapper(LOCK_EX | LOCK_NB)
  }

  func lock() throws {
    _ = try flockWrapper(LOCK_EX)
  }

  func unlock() throws {
    _ = try flockWrapper(LOCK_UN)
  }

  func flockWrapper(_ operation: Int32) throws -> Bool {
    if ProcessInfo.processInfo.environment.keys.contains("TART_NO_FILE_LOCKING") {
      return true
    }

    let ret = flock(fd, operation)
    if ret != 0 {
      let details = Errno(rawValue: CInt(errno))

      if (operation & LOCK_NB) != 0 && details == .wouldBlock {
        return false
      }

      throw FileLockError.Failed("failed to lock \(url): \(details)")
    }

    return true
  }
}
