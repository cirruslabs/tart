import Foundation
import Virtualization

struct UnsupportedRestoreImageError: Error {
}

struct NoMainScreenFoundError: Error {
}

struct DownloadFailed: Error {
}

class VM: NSObject, VZVirtualMachineDelegate, ObservableObject {
  // Virtualization.Framework's virtual machine
  @Published var virtualMachine: VZVirtualMachine

  // Semaphore used to communicate with the VZVirtualMachineDelegate
  var sema = DispatchSemaphore(value: 0)

  // VM's config
  var name: String
  
  // VM's config
  var config: VMConfig

  init(vmDir: VMDirectory) throws {
    let auxStorage = VZMacAuxiliaryStorage(contentsOf: vmDir.nvramURL)

    name = vmDir.name
    config = try VMConfig.init(fromURL: vmDir.configURL)

    let configuration = try VM.craftConfiguration(diskURL: vmDir.diskURL, auxStorage: auxStorage, vmConfig: config)
    virtualMachine = VZVirtualMachine(configuration: configuration)

    super.init()

    virtualMachine.delegate = self
  }

  static func retrieveLatestIPSW() async throws -> URL {
    defaultLogger.appendNewLine("Looking up the latest supported IPSW...")
    let image = try await withCheckedThrowingContinuation { continuation in
      VZMacOSRestoreImage.fetchLatestSupported() { result in
        continuation.resume(with: result)
      }
    }


    let ipswCacheFolder = Config.tartCacheDir.appendingPathComponent("IPSWs", isDirectory: true)
    try FileManager.default.createDirectory(at: ipswCacheFolder, withIntermediateDirectories: true)

    let expectedIPSWLocation = ipswCacheFolder.appendingPathComponent("\(image.buildVersion).ipsw", isDirectory: false)

    if FileManager.default.fileExists(atPath: expectedIPSWLocation.path) {
      defaultLogger.appendNewLine("Using cached *.ipsw file...")
      return expectedIPSWLocation
    }

    defaultLogger.appendNewLine("Fetching \(expectedIPSWLocation.lastPathComponent)...")

    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let downloadedTask = URLSession.shared.dataTask(with: image.url) { data, response, error in
        if error != nil {
          continuation.resume(throwing: error!)
          return
        }
        if (data == nil) {
          continuation.resume(throwing: DownloadFailed())
          return
        }
        continuation.resume(returning: data!)
      }
      ProgressObserver(downloadedTask.progress).log(defaultLogger)
      downloadedTask.resume()
    }

    try data.write(to: expectedIPSWLocation, options: [.atomic])
    return expectedIPSWLocation
  }

  init(vmDir: VMDirectory, ipswURL: URL?, diskSizeGB: UInt8) async throws {
    let ipswURL = ipswURL != nil ? ipswURL! : try await VM.retrieveLatestIPSW();

    // Load the restore image and try to get the requirements
    // that match both the image and our platform
    let image = try await withCheckedThrowingContinuation { continuation in
      VZMacOSRestoreImage.load(from: ipswURL) { result in
        continuation.resume(with: result)
      }
    }

    guard let requirements = image.mostFeaturefulSupportedConfiguration else {
      throw UnsupportedRestoreImageError()
    }

    // Create NVRAM
    let auxStorage = try VZMacAuxiliaryStorage(creatingStorageAt: vmDir.nvramURL, hardwareModel: requirements.hardwareModel)

    // Create disk
    try vmDir.resizeDisk(diskSizeGB)

    name = vmDir.name
    // Create config
    config = VMConfig(
      hardwareModel: requirements.hardwareModel,
      cpuCountMin: requirements.minimumSupportedCPUCount,
      memorySizeMin: requirements.minimumSupportedMemorySize
    )
    // allocate at least 4 CPUs because otherwise VMs are frequently freezing
    try config.setCPU(cpuCount: max(4, requirements.minimumSupportedCPUCount))
    try config.save(toURL: vmDir.configURL)

    // Initialize the virtual machine and its configuration
    let configuration = try VM.craftConfiguration(diskURL: vmDir.diskURL, auxStorage: auxStorage, vmConfig: config)
    virtualMachine = VZVirtualMachine(configuration: configuration)

    super.init()

    virtualMachine.delegate = self

    // Run automated installation
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.main.async {
        let installer = VZMacOSInstaller(virtualMachine: self.virtualMachine, restoringFromImageAt: ipswURL)

        defaultLogger.appendNewLine("Installing OS...")
        ProgressObserver(installer.progress).log(defaultLogger)

        installer.install { result in
          continuation.resume(with: result)
        }
      }
    }
  }

  func run() async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        self.virtualMachine.start(completionHandler: { result in
          continuation.resume(with: result)
        })
      }
    }

    await withTaskCancellationHandler(operation: {
      sema.wait()
    }, onCancel: {
      sema.signal()
    })

    if Task.isCancelled {
      DispatchQueue.main.sync {
        Task {
          try await self.virtualMachine.stop()
        }
      }
    }
  }

  static func craftConfiguration(diskURL: URL, auxStorage: VZMacAuxiliaryStorage, vmConfig: VMConfig) throws -> VZVirtualMachineConfiguration {
    let configuration = VZVirtualMachineConfiguration()

    // Boot loader
    configuration.bootLoader = VZMacOSBootLoader()

    // CPU and memory
    configuration.cpuCount = vmConfig.cpuCount
    configuration.memorySize = vmConfig.memorySize

    // Platform
    let platform = VZMacPlatformConfiguration()

    platform.machineIdentifier = vmConfig.ecid
    platform.auxiliaryStorage = auxStorage
    platform.hardwareModel = vmConfig.hardwareModel

    configuration.platform = platform

    // Display
    let graphicsDeviceConfiguration = VZMacGraphicsDeviceConfiguration()
    graphicsDeviceConfiguration.displays = [
      VZMacGraphicsDisplayConfiguration(
        widthInPixels: vmConfig.display.width,
        heightInPixels: vmConfig.display.height,
        pixelsPerInch: vmConfig.display.dpi
      )
    ]
    configuration.graphicsDevices = [graphicsDeviceConfiguration]

    // Audio
    let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
    soundDeviceConfiguration.streams = [VZVirtioSoundDeviceInputStreamConfiguration(), VZVirtioSoundDeviceOutputStreamConfiguration()]
    configuration.audioDevices = [soundDeviceConfiguration]

    // Keyboard and mouse
    configuration.keyboards = [VZUSBKeyboardConfiguration()]
    configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

    // Networking
    let vio = VZVirtioNetworkDeviceConfiguration()
    vio.attachment = VZNATNetworkDeviceAttachment()
    vio.macAddress = vmConfig.macAddress
    configuration.networkDevices = [vio]

    // Storage
    let attachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
    let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
    configuration.storageDevices = [storage]

    // Entropy
    configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

    try configuration.validate()

    return configuration
  }

  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    print("guest has stopped the virtual machine")
    sema.signal()
  }

  func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
    print("guest has stopped the virtual machine due to error")
    sema.signal()
  }

  func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
    print("virtual machine's network attachment \(networkDevice) has been disconnected with error: \(error)")
    sema.signal()
  }
}
