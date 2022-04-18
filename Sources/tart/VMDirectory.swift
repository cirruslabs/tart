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
  
  func resizeDisk(_ sizeGB: UInt8) throws {
    if !FileManager.default.fileExists(atPath: diskURL.path) {
      FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
    }
    let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
    // macOS considers kilo being 1000 and not 1024
    try diskFileHandle.truncate(atOffset: UInt64(sizeGB) * 1000 * 1000 * 1000)
    try diskFileHandle.close()
  }
}
