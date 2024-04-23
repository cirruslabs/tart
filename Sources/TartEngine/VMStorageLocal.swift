import Foundation

package class VMStorageLocal: PrunableStorage {
  let baseURL: URL

  package init(config: any ConfigProtocol) {
    baseURL = config.tartVMsDir
  }


  private func vmURL(_ name: String) -> URL {
    baseURL.appendingPathComponent(name, isDirectory: true)
  }

  package func exists(_ name: String) -> Bool {
    VMDirectory(baseURL: vmURL(name)).initialized
  }

  package func open(_ name: String) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.validate(userFriendlyName: name)

    try vmDir.baseURL.updateAccessDate()

    return vmDir
  }

  package func create(_ name: String, overwrite: Bool = false) throws -> VMDirectory {
    let vmDir = VMDirectory(baseURL: vmURL(name))

    try vmDir.initialize(overwrite: overwrite)

    return vmDir
  }

  package func move(_ name: String, from: VMDirectory) throws {
    _ = try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    _ = try FileManager.default.replaceItemAt(vmURL(name), withItemAt: from.baseURL)
  }

  package func rename(_ name: String, _ newName: String) throws {
    _ = try FileManager.default.replaceItemAt(vmURL(newName), withItemAt: vmURL(name))
  }

  package func delete(_ name: String) throws {
    try VMDirectory(baseURL: vmURL(name)).delete()
  }

  package func list() throws -> [(String, VMDirectory)] {
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

  package func prunables() throws -> [Prunable] {
    try list().map { (_, vmDir) in vmDir }
  }

  package func hasVMsWithMACAddress(macAddress: String) throws -> Bool {
    try list().contains { try $1.macAddress() == macAddress }
  }
}
