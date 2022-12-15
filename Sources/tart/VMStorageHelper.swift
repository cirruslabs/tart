import Foundation

class VMStorageHelper {
  static func open(_ name: String) throws -> VMDirectory {
    try missingVMWrap(name) {
      if let remoteName = try? RemoteName(name) {
        return try VMStorageOCI().open(remoteName)
      } else {
        return try VMStorageLocal().open(name)
      }
    }
  }

  static func delete(_ name: String) throws {
    try missingVMWrap(name) {
      if let remoteName = try? RemoteName(name) {
        try VMStorageOCI().delete(remoteName)
      } else {
        try VMStorageLocal().delete(name)
      }
    }
  }

  private static func missingVMWrap<R: Any>(_ name: String, closure: () throws -> R) throws -> R {
    do {
      return try closure()
    } catch {
      if error.isFileNotFound() {
        throw RuntimeError("source VM \"\(name)\" not found, is it listed in \"tart list\"?")
      }

      throw error
    }
  }
}

extension Error {
  func isFileNotFound() -> Bool {
    (self as NSError).code == NSFileReadNoSuchFileError
  }
}

class RuntimeError: Error, CustomStringConvertible {
  let message: String
  let exitCode: Int32

  init(_ message: String, exitCode: Int32 = 1) {
    self.message = message
    self.exitCode = exitCode
  }

  var description: String {
    message
  }
}

extension RuntimeError : CustomNSError {
  var errorUserInfo: [String : Any] {
    [
      NSDebugDescriptionErrorKey: message,
    ]
  }
}
