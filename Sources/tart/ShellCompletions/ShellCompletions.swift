import Foundation

fileprivate func normalizeName(_ name: String) -> String {
  // Colons are misinterpreted by Zsh completion
  return name.replacingOccurrences(of: ":", with: "\\:")
}

func completeMachines(_ arguments: [String], _ argumentIdx: Int, _ argumentPrefix: String) -> [String] {
  let localVMs = (try? VMStorageLocal().list().map { name, _ in
    normalizeName(name)
  }) ?? []
  let ociVMs = (try? VMStorageOCI().list().map { name, _, _ in
    normalizeName(name)
  }) ?? []
  return (localVMs + ociVMs)
}

func completeLocalMachines(_ arguments: [String], _ argumentIdx: Int, _ argumentPrefix: String) -> [String] {
  let localVMs = (try? VMStorageLocal().list()) ?? []
  return localVMs.map { name, _ in normalizeName(name) }
}

func completeRunningMachines(_ arguments: [String], _ argumentIdx: Int, _ argumentPrefix: String) -> [String] {
  let localVMs = (try? VMStorageLocal().list()) ?? []
  return localVMs
    .filter { _, vmDir in (try? vmDir.state() == .Running) ?? false}
    .map { name, _ in normalizeName(name) }
}
