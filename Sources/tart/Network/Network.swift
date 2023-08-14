import Virtualization

protocol Network {
  func attachments() -> [VZNetworkDeviceAttachment]
  func run(_ sema: DispatchSemaphore) throws
  func stop() async throws
}
