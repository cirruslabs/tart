import Foundation
import Virtualization

struct UnsupportedRestoreImageError: Error {}
struct NoMainScreenFoundError: Error {}

class VM: NSObject, VZVirtualMachineDelegate, ObservableObject {
    // Virtualization.Framework's virtual machine
    @Published var virtualMachine: VZVirtualMachine
    
    // Semaphore used to communicate with the VZVirtualMachineDelegate
    var sema = DispatchSemaphore(value: 0)
    
    // VM's config
    var vmConfig: VMConfig
    
    init(vmDir: VMDirectory) throws {
        let auxStorage = VZMacAuxiliaryStorage(contentsOf: vmDir.nvramURL)
        
        self.vmConfig = try VMConfig.init(fromURL: vmDir.configURL)
        
        let configuration = try VM.craftConfiguration(
            diskURL: vmDir.diskURL,
            ecid: vmConfig.ecid,
            auxStorage: auxStorage,
            hardwareModel: vmConfig.hardwareModel,
            cpuCount: vmConfig.cpuCount,
            memorySize: vmConfig.memorySize,
            macAddress: vmConfig.macAddress
        )
        
        self.virtualMachine = VZVirtualMachine(configuration: configuration)
        
        super.init()
        
        self.virtualMachine.delegate = self
    }
    
    static func retrieveLatestIPSW() async throws -> URL {
        defaultLogger.appendNewLine("Looking up the latest supported IPSW...")
        let image = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.fetchLatestSupported() { result in continuation.resume(with: result) }
        }
        defaultLogger.appendNewLine("Fetching...")

        return try await withCheckedThrowingContinuation { continuation in
            let downloadedTask = URLSession.shared.downloadTask(with: image.url) { location, _, error in
                if (location != nil) {
                    continuation.resume(returning: location!)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
            ProgressLogger(defaultLogger).FollowProgress(downloadedTask.progress)
            downloadedTask.resume()
        }
    }
    
    init(vmDir: VMDirectory, ipswURL: URL?, diskSize: UInt64 = 32 * 1024 * 1024 * 1024) async throws {
        let ipswURL = ipswURL != nil ? ipswURL! : try await VM.retrieveLatestIPSW();
        
        // Load the restore image and try to get the requirements
        // that match both the image and our platform
        let image = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.load(from: ipswURL) { result in continuation.resume(with: result) }
        }
        
        guard let requirements = image.mostFeaturefulSupportedConfiguration else { throw UnsupportedRestoreImageError() }
        
        // Create NVRAM
        let auxStorage = try VZMacAuxiliaryStorage(creatingStorageAt: vmDir.nvramURL, hardwareModel: requirements.hardwareModel)
        
        // Create disk
        FileManager.default.createFile(atPath: vmDir.diskURL.path, contents: nil, attributes: nil)
        let diskFileHandle = try FileHandle.init(forWritingTo: vmDir.diskURL)
        try diskFileHandle.truncate(atOffset: diskSize)
        try diskFileHandle.close()
        
        // Create config
        self.vmConfig = VMConfig(
            hardwareModel: requirements.hardwareModel,
            cpuCount: requirements.minimumSupportedCPUCount,
            memorySize: requirements.minimumSupportedMemorySize
        )
        try self.vmConfig.save(toURL: vmDir.configURL)
        
        // Initialize the virtual machine and its configuration
        let configuration = try VM.craftConfiguration(
            diskURL: vmDir.diskURL,
            ecid: self.vmConfig.ecid,
            auxStorage: auxStorage,
            hardwareModel: requirements.hardwareModel,
            cpuCount: self.vmConfig.cpuCount,
            memorySize: self.vmConfig.memorySize,
            macAddress: self.vmConfig.macAddress
        )
        self.virtualMachine = VZVirtualMachine(configuration: configuration)
        
        super.init()
        
        self.virtualMachine.delegate = self
        
        // Run automated installation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                let installer = VZMacOSInstaller(virtualMachine: self.virtualMachine, restoringFromImageAt: ipswURL)

                defaultLogger.appendNewLine("Installing OS...")        
                ProgressLogger(defaultLogger).FollowProgress(installer.progress)        
                
                installer.install { result in continuation.resume(with: result) }
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
        
        sema.wait()
    }
    
    static func craftConfiguration(
        diskURL: URL,
        ecid: VZMacMachineIdentifier,
        auxStorage: VZMacAuxiliaryStorage,
        hardwareModel: VZMacHardwareModel,
        cpuCount: Int,
        memorySize: UInt64,
        macAddress: VZMACAddress
    ) throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()
        
        // Boot loader
        configuration.bootLoader = VZMacOSBootLoader()
        
        // CPU and memory
        configuration.cpuCount = cpuCount
        configuration.memorySize = memorySize
        
        // Platform
        let platform = VZMacPlatformConfiguration()
        
        platform.machineIdentifier = ecid
        platform.auxiliaryStorage = auxStorage
        platform.hardwareModel = hardwareModel
        
        configuration.platform = platform
        
        // Display
        let graphicsDeviceConfiguration = VZMacGraphicsDeviceConfiguration()
        guard let mainScreen = NSScreen.main else {
            throw NoMainScreenFoundError()
        }
        graphicsDeviceConfiguration.displays = [
            VZMacGraphicsDisplayConfiguration(for: mainScreen, sizeInPoints: mainScreen.frame.size)
        ]
        configuration.graphicsDevices = [graphicsDeviceConfiguration]
        
        // Keyboard and mouse
        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        
        // Networking
        let vio = VZVirtioNetworkDeviceConfiguration()
        vio.attachment = VZNATNetworkDeviceAttachment()
        vio.macAddress = macAddress
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
        print("virtual machine's network attachment has been disconnected")
        sema.signal()
    }
}
