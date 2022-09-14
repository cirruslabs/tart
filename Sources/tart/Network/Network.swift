import Virtualization

protocol Network {
  func attachment() -> VZNetworkDeviceAttachment
  func run() throws
  func stop() throws
}
