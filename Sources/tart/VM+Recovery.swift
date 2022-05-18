import Foundation
import Virtualization

// Originally found by @saagarjha
// See https://github.com/saagarjha/VirtualApple/blob/c737f41dae24c40996ded7dccb222b160c857de8/VirtualApple/VirtualMachine.swift#L135-L145

@objc protocol _VZVirtualMachine {
  @objc(_startWithOptions:completionHandler:)
  func _start(with options: _VZVirtualMachineStartOptions) async throws
}

@objc protocol _VZVirtualMachineStartOptions {
  init()
  var bootMacOSRecovery: Bool { get set }
}

extension VZVirtualMachine {
  func start(_ recovery: Bool) async throws {
    let options = unsafeBitCast(NSClassFromString("_VZVirtualMachineStartOptions")!, to: _VZVirtualMachineStartOptions.Type.self).init()
    options.bootMacOSRecovery = recovery
    try await unsafeBitCast(self, to: _VZVirtualMachine.self)._start(with: options)
  }
}
