import Foundation
import System

enum FileLockError: Error, Equatable {
    case Failed(_ message: String)
    case AlreadyLocked
}

class FileLock {
    let url: URL
    let fh: FileHandle

    init(lockURL: URL) throws {
        url = lockURL
        fh = try FileHandle(forWritingTo: lockURL)
    }

    deinit {
        try! fh.close()
    }

    func trylock() throws {
        try flockWrapper(LOCK_EX | LOCK_NB)
    }

    func lock() throws {
        try flockWrapper(LOCK_EX)
    }

    func unlock() throws {
        try flockWrapper(LOCK_UN)
    }

    func flockWrapper(_ operation: Int32) throws {
        let ret = flock(fh.fileDescriptor, operation)
        if ret != 0 {
            let details = Errno(rawValue: CInt(errno))

            if (operation & LOCK_NB) != 0 && details == .wouldBlock {
                throw FileLockError.AlreadyLocked
            }

            throw FileLockError.Failed("failed to lock \(url): \(details)")
        }
    }
}
