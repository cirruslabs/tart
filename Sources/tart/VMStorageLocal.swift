import Foundation

class VMStorageLocal {
  let baseURL: URL = Config.tartHomeDir.appendingPathComponent("vms", isDirectory: true)

  private func vmURL(_ name: String) -> URL {
    baseURL.appendingPathComponent(name, isDirectory: true)
  }

  func exists(_ name: String) -> Bool {
    VMDirectory(baseURL: vmURL(name)).initialized
  }

  func open(_ name: String) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.validate()

    return vmDir
  }

  func create(_ name: String, overwrite: Bool = false) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.initialize(overwrite: overwrite)

    return vmDir
  }

  func move(_ name: String, from: VMDirectory) throws {
    let newVmURL = vmURL(name)
    _ = try FileManager.default.createDirectory(at: newVmURL, withIntermediateDirectories: true)
    _ = try FileManager.default.replaceItemAt(newVmURL, withItemAt: from.baseURL)
  }

  func delete(_ name: String) throws {
    try FileManager.default.removeItem(at: vmURL(name))
  }

  func list() throws -> [(String, VMDirectory)] {
    do {
      return try FileManager.default.contentsOfDirectory(
        at: baseURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsSubdirectoryDescendants).compactMap { url in
        let vmDir = VMDirectory(baseURL: url)

        if !vmDir.initialized {
          return nil
        }

        return (vmDir.name, vmDir)
      }
    } catch {
      if error.isFileNotFound() {
        return []
      }

      throw error
    }
  }
}
