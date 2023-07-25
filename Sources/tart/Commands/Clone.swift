import ArgumentParser
import Foundation
import SystemConfiguration

struct Clone: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Clone a VM",
    discussion: """
    Creates a local virtual machine by cloning either a remote or another local virtual machine.

    Due to copy-on-write magic in Apple File System a cloned VM won't actually claim all the space right away.
    Only changes to a cloned disk will be written and claim new space. By default, Tart checks available capacity
    in Tart's home directory and checks if there is enough space for the worst possible scenario: when the whole disk
    will be modified.

    This behaviour can be disabled by setting TART_NO_AUTO_PRUNE environment variable. This might be helpful
    for use cases when the original image is very big and a workload is known to only modify a fraction of the cloned disk.
    """
  )

  @Argument(help: "source VM name")
  var sourceName: String

  @Argument(help: "new VM name")
  var newName: String

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

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

      try lock.unlock()

      // APFS is doing copy-on-write so the above cloning operation (just copying files on disk)
      // is not actually claiming new space until the VM is started and it writes something to disk.
      // So once we clone the VM let's try to claim a little bit of space for the VM to run.
      try Prune.reclaimIfNeeded(UInt64(sourceVM.sizeBytes()), sourceVM)
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}
