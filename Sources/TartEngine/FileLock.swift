import Foundation
import System

package enum FileLockError: Error, Equatable {
  case Failed(_ message: String)
  case AlreadyLocked
}

package class FileLock {
  let url: URL
  let fd: Int32

  package init(lockURL: URL) throws {
    url = lockURL
    fd = open(lockURL.path, 0)
  }

  deinit {
    close(fd)
  }

  package func trylock() throws -> Bool {
    try flockWrapper(LOCK_EX | LOCK_NB)
  }

  package func lock() throws {
    _ = try flockWrapper(LOCK_EX)
  }

  package func unlock() throws {
    _ = try flockWrapper(LOCK_UN)
  }

  func flockWrapper(_ operation: Int32) throws -> Bool {
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
