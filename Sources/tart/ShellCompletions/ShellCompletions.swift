import Foundation

fileprivate func normalizeName(_ name: String) -> String {
  // Colons are misinterpreted by Zsh completion
  return name.replacingOccurrences(of: ":", with: "\\:")
}

func completeMachines(_ arguments: [String]) -> [String] {
  let localVMs = (try? VMStorageLocal().list().map { name, _ in
    normalizeName(name)
  }) ?? []
  let ociVMs = (try? VMStorageOCI().list().map { name, _, _ in
    normalizeName(name)
  }) ?? []
  return (localVMs + ociVMs)
}

func completeLocalMachines(_ arguments: [String]) -> [String] {
  if let vms = try? VMStorageLocal().list() {
    return vms.map { name, vmDir in
      return name
    }
  }
  return []
}

//func completeMachines(_ arguments: [String]) -> [String] {
//  if let vms = try? VMStorageLocal().list() {
//    return vms.enumerated().map { (index, data) in
//      let (name, vmDir) = data
//      return "name\(String(describing: name.first!))"
//    }
//  }
//  return ["siemka"]
//}

func completeRunningMachines(_ arguments: [String]) -> [String] {
  if let vms = try? VMStorageLocal().list() {
    return vms
      .filter { (_, vm) in
        if let state = try? vm.state() {
          return state == "running"
        }
        return false
      }
      .map { (name, _) in
        return name
      }
  }
  return []
}

func completeActiveMachines(_ arguments: [String]) -> [String] {
  if let vms = try? VMStorageLocal().list() {
    return vms
      .filter { (_, vm) in
        if let state = try? vm.state() {
          return state == "suspended" || state == "running"
        }
        return false
      }
      .map { (name, _) in
        return name
      }
  }
  return []
}
