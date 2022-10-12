import Virtualization

protocol Network {
  func attachment() -> VZNetworkDeviceAttachment
  func run(_ sema: DispatchSemaphore) throws
  func stop() async throws
}
