import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Clone a VM")

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  @Option(help: ArgumentHelp(
    "Amount of disk space in GB to try to remain available after cloning for future runs of virtual machines.",
    discussion: """
    Apple File System is using copy-on-write so a cloned VM is not claiming disk until it gets executed and starts actually writing to the disk.
    This argument allows to automatically make sure that there is some space left for successful VMs execution in the future.
    """,
    visibility: .hidden))
  var diskSizeToMakeAvailable: UInt64 = 50

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  func run() async throws {
    let ociStorage = VMStorageOCI()
    let localStorage = VMStorageLocal()

    if let remoteName = try? RemoteName(sourceName), !ociStorage.exists(remoteName) {
      // Pull the VM in case it's OCI-based and doesn't exist locally yet
      let registry = try Registry(host: remoteName.host, namespace: remoteName.namespace, insecure: insecure)
      try await ociStorage.pull(remoteName, registry: registry)
    }

    let sourceVM = try VMStorageHelper.open(sourceName)
    let tmpVMDir = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(operation: {
      // Acquire a global lock
      let lock = try FileLock(lockURL: Config().tartHomeDir)
      try lock.lock()

      let generateMAC = try localStorage.hasVMsWithMACAddress(macAddress: sourceVM.macAddress())
        && sourceVM.state() != "suspended"
      try sourceVM.clone(to: tmpVMDir, generateMAC: generateMAC)

      try localStorage.move(newName, from: tmpVMDir)

      // APFS is doing copy-on-write so the above cloning operation (just copying files on disk)
      // is not actually claiming new space until the VM is started and it writes something to disk.
      // So once we clone the VM let's try to claim a little bit of space for the VM to run.
      try Prune.reclaimIfNeeded(
        min(
          UInt64(sourceVM.sizeBytes()), // no need to claim more then the VM size
          diskSizeToMakeAvailable * 1000 * 1000 * 1000
        )
      )

      try lock.unlock()
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}
