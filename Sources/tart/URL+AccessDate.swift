import Foundation

extension URL {
  func accessDate() throws -> Date {
    let attrs = try resourceValues(forKeys: [.contentAccessDateKey])
    return attrs.contentAccessDate!
  }

  func updateAccessDate(_ accessDate: Date = Date()) throws {
    let attrs = try resourceValues(forKeys: [.contentAccessDateKey])
    let modificationDate = attrs.contentAccessDate!

    let times = [accessDate.asTimeval(), modificationDate.asTimeval()]
    let ret = utimes(path, times)
    if ret != 0 {
      throw RuntimeError.FailedToUpdateAccessDate("utimes(2) failed: \(ret.explanation())")
    }
  }
}

extension Date {
  func asTimeval() -> timeval {
    timeval(tv_sec: Int(timeIntervalSince1970), tv_usec: 0)
  }
}
