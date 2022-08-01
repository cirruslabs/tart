import ArgumentParser
import Dispatch
import SwiftUI
import SwiftDate

struct Prune: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Prune OCI and IPSW caches")

  @Option(help: ArgumentHelp("Remove cache entries last accessed more than n days ago",
    discussion: "For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7 days.",
    valueName: "n"))
  var olderThan: UInt?

  @Option(help: ArgumentHelp("Remove least recently used cache entries that do not fit the specified cache size budget n, expressed in gigabytes",
    discussion: "For example, --cache-budget=50 will effectively shrink all caches to a total size of 50 gigabytes.",
    valueName: "n"))
  var cacheBudget: UInt?

  func validate() throws {
    if olderThan == nil && cacheBudget == nil {
      throw ValidationError("at least one criteria must be specified")
    }
  }

  func run() async throws {
    do {
      // Clean up cache entries based on last accessed date
      if let olderThan = olderThan {
        let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
        let olderThanDate = Date().addingTimeInterval(olderThanInterval)

        try Prune.pruneOlderThan(olderThanDate: olderThanDate)
      }

      // Clean up cache entries based on imposed cache size limit and entry's last accessed date
      if let cacheBudget = cacheBudget {
        try Prune.pruneCacheBudget(cacheBudgetBytes: UInt64(cacheBudget) * 1024 * 1024 * 1024)
      }

      Foundation.exit(0)
    } catch {
      print(error)

      Foundation.exit(1)
    }
  }

  static func pruneOlderThan(olderThanDate: Date) throws {
    let prunableStorages: [PrunableStorage] = [VMStorageOCI(), try IPSWCache()]
    let prunables: [Prunable] = try prunableStorages.flatMap { try $0.prunables() }

    try prunables.filter { try $0.accessDate() <= olderThanDate }.forEach { try $0.delete() }
  }

  static func pruneCacheBudget(cacheBudgetBytes: UInt64) throws {
    let prunableStorages: [PrunableStorage] = [VMStorageOCI(), try IPSWCache()]
    let prunables: [Prunable] = try prunableStorages
            .flatMap { try $0.prunables() }
            .sorted { try $0.accessDate() < $1.accessDate() }

    let cacheUsedBytes = try prunables.map { try $0.sizeBytes() }.reduce(0, +)
    var cacheReclaimedBytes: Int = 0

    var it = prunables.makeIterator()

    while (cacheUsedBytes - cacheReclaimedBytes) > cacheBudgetBytes {
      guard let prunable = it.next() else {
        break
      }

      cacheReclaimedBytes -= try prunable.sizeBytes()
      try prunable.delete()
    }
  }

  static func pruneReclaim(reclaimBytes: UInt64) throws {
    let prunableStorages: [PrunableStorage] = [VMStorageOCI(), try IPSWCache()]
    let prunables: [Prunable] = try prunableStorages
            .flatMap { try $0.prunables() }
            .sorted { try $0.accessDate() < $1.accessDate() }

    // Does it even make sense to start?
    let cacheUsedBytes = try prunables.map { try $0.sizeBytes() }.reduce(0, +)
    if cacheUsedBytes < reclaimBytes {
      return
    }

    var cacheReclaimedBytes: Int = 0

    var it = prunables.makeIterator()

    while cacheReclaimedBytes <= reclaimBytes {
      guard let prunable = it.next() else {
        break
      }

      cacheReclaimedBytes -= try prunable.sizeBytes()
      try prunable.delete()
    }
  }
}
