import Foundation
import TartEngine

fileprivate func normalizeName(_ name: String) -> String {
  // Colons are misinterpreted by Zsh completion
  return name.replacingOccurrences(of: ":", with: "\\:")
}

func completeMachines(_ arguments: [String]) -> [String] {
  let localVMs = (try? VMStorageLocal(config: Config.processConfig).list().map { name, _ in
    normalizeName(name)
  }) ?? []
  let ociVMs = (try? VMStorageOCI(config: Config.processConfig).list().map { name, _, _ in
    normalizeName(name)
  }) ?? []
  return (localVMs + ociVMs)
}

func completeLocalMachines(_ arguments: [String]) -> [String] {
  let localVMs = (try? VMStorageLocal(config: Config.processConfig).list()) ?? []
  return localVMs.map { name, _ in normalizeName(name) }
}

func completeRunningMachines(_ arguments: [String]) -> [String] {
  let localVMs = (try? VMStorageLocal(config: Config.processConfig).list()) ?? []
  return localVMs
    .filter { _, vmDir in (try? vmDir.state() == .Running) ?? false}
    .map { name, _ in normalizeName(name) }
}
