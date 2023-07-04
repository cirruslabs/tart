import ArgumentParser
import Foundation

struct Import: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

  @Argument(help: "Path to a file created with \"tart export\".")
  var path: String

  @Argument(help: "Destination VM name.")
  var name: String

  func validate() throws {
    if name.contains("/") {
      throw ValidationError("<name> should be a local name")
    }
  }

  func run() async throws {
    let localStorage = VMStorageLocal()

    // Create a temporary VM directory to which we will load the export file
    let tmpVMDir = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    // while we're running
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    // Populate the temporary VM directory with the export file contents
    print("importing...")
    try tmpVMDir.importFromArchive(path: path)

    try await withTaskCancellationHandler(operation: {
      // Acquire a global lock
      let lock = try FileLock(lockURL: Config().tartHomeDir)
      try lock.lock()

      try localStorage.move(name, from: tmpVMDir)

      try lock.unlock()
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}
