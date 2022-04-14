import Foundation

struct UninitializedVMDirectoryError: Error {
}

struct AlreadyInitializedVMDirectoryError: Error {
}

struct VMDirectory {
  var name: String
  var baseURL: URL

  var configURL: URL {
    baseURL.appendingPathComponent("config.json")
  }
  var diskURL: URL {
    baseURL.appendingPathComponent("disk.img")
  }
  var nvramURL: URL {
    baseURL.appendingPathComponent("nvram.bin")
  }

  var initialized: Bool {
    FileManager.default.fileExists(atPath: configURL.path) &&
      FileManager.default.fileExists(atPath: diskURL.path) &&
      FileManager.default.fileExists(atPath: nvramURL.path)
  }

  func initialize() throws {
    if initialized {
      throw AlreadyInitializedVMDirectoryError()
    }

    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
  }

  func validate() throws {
    if !initialized {
      throw UninitializedVMDirectoryError()
    }
  }
}
