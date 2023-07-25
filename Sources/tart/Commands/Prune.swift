import ArgumentParser
import Dispatch
import Sentry
import SwiftUI
import SwiftDate

struct Prune: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Prune OCI and IPSW caches or local VMs")

  @Option(help: ArgumentHelp("Entries to remove: \"caches\" targets OCI and IPSW caches and \"vms\" targets local VMs."))
  var entries: String = "caches"

  @Option(help: ArgumentHelp("Remove entries that were last accessed more than n days ago",
                             discussion: "For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7 days.",
                             valueName: "n"))
  var olderThan: UInt?

  @Option(help: .hidden)
  var cacheBudget: UInt?

  @Option(help: ArgumentHelp("Remove the least recently used entries that do not fit the specified space size budget n, expressed in gigabytes",
                             discussion: "For example, --space-budget=50 will effectively shrink all entries to a total size of 50 gigabytes.",
                             valueName: "n"))
  var spaceBudget: UInt?

  @Flag(help: .hidden)
  var gc: Bool = false

  mutating func validate() throws {
    // --cache-budget deprecation logic
    if let cacheBudget = cacheBudget {
      fputs("--cache-budget is deprecated, please use --space-budget\n", stderr)

      if spaceBudget != nil {
        throw ValidationError("--cache-budget is deprecated, please use --space-budget")
      }

      spaceBudget = cacheBudget
    }

    if olderThan == nil && spaceBudget == nil && !gc {
      throw ValidationError("at least one pruning criteria must be specified")
    }
  }

  func run() async throws {
    if gc {
      try VMStorageOCI().gc()
    }

    // Build a list of prunable storages that we're going to prune based on user's request
    let prunableStorages: [PrunableStorage]

    switch entries {
    case "caches":
      prunableStorages = [VMStorageOCI(), try IPSWCache()]
    case "vms":
      prunableStorages = [VMStorageLocal()]
    default:
      throw ValidationError("unsupported --entries value, please specify either \"caches\" or \"vms\"")
    }

    // Clean up cache entries based on last accessed date
    if let olderThan = olderThan {
      let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
      let olderThanDate = Date() - olderThanInterval

      try Prune.pruneOlderThan(prunableStorages: prunableStorages, olderThanDate: olderThanDate)
    }

    // Clean up cache entries based on imposed cache size limit and entry's last accessed date
    if let spaceBudget = spaceBudget {
      try Prune.pruneSpaceBudget(prunableStorages: prunableStorages, spaceBudgetBytes: UInt64(spaceBudget) * 1024 * 1024 * 1024)
    }
  }

  static func pruneOlderThan(prunableStorages: [PrunableStorage], olderThanDate: Date) throws {
    let prunables: [Prunable] = try prunableStorages.flatMap { try $0.prunables() }

    try prunables.filter { try $0.accessDate() <= olderThanDate }.forEach { try $0.delete() }
  }

  static func pruneSpaceBudget(prunableStorages: [PrunableStorage], spaceBudgetBytes: UInt64) throws {
    let prunables: [Prunable] = try prunableStorages
      .flatMap { try $0.prunables() }
      .sorted { try $0.accessDate() > $1.accessDate() }

    var spaceBudgetBytes = spaceBudgetBytes
    var prunablesToDelete: [Prunable] = []

    for prunable in prunables {
      let prunableSizeBytes = UInt64(try prunable.sizeBytes())

      if prunableSizeBytes <= spaceBudgetBytes {
        // Don't mark for deletion as
        // there's a budget available
        spaceBudgetBytes -= prunableSizeBytes
      } else {
        // Mark for deletion
        prunablesToDelete.append(prunable)
      }
    }

    try prunablesToDelete.forEach { try $0.delete() }
  }

  static func reclaimIfNeeded(_ requiredBytes: UInt64, _ initiator: Prunable? = nil) throws {
    if ProcessInfo.processInfo.environment.keys.contains("TART_NO_AUTO_PRUNE") {
      return
    }

    SentrySDK.configureScope { scope in
      scope.setContext(value: ["requiredBytes": requiredBytes], key: "Prune")
    }

    // Figure out how much disk space is available
    let attrs = try Config().tartCacheDir.resourceValues(forKeys: [
      .volumeAvailableCapacityKey,
      .volumeAvailableCapacityForImportantUsageKey
    ])
    let volumeAvailableCapacityCalculated = max(
      UInt64(attrs.volumeAvailableCapacity!),
      UInt64(attrs.volumeAvailableCapacityForImportantUsage!)
    )

    SentrySDK.configureScope { scope in
      scope.setContext(value: [
        "volumeAvailableCapacity": attrs.volumeAvailableCapacity!,
        "volumeAvailableCapacityForImportantUsage": attrs.volumeAvailableCapacityForImportantUsage!,
        "volumeAvailableCapacityCalculated": volumeAvailableCapacityCalculated
      ], key: "Prune")
    }

    if volumeAvailableCapacityCalculated <= 0 {
      SentrySDK.capture(message: "Zero volume capacity reported") { scope in
        scope.setLevel(.warning)
      }

      return
    }

    // Now that we know how much free space is left,
    // check if we even need to reclaim anything
    if requiredBytes < volumeAvailableCapacityCalculated {
      return
    }

    try Prune.reclaimIfPossible(requiredBytes - volumeAvailableCapacityCalculated, initiator)
  }

  private static func reclaimIfPossible(_ reclaimBytes: UInt64, _ initiator: Prunable? = nil) throws {
    let transaction = SentrySDK.startTransaction(name: "Pruning cache", operation: "prune", bindToScope: true)
    defer { transaction.finish() }

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

      if prunable.url == initiator?.url.resolvingSymlinksInPath() {
        // do not prune the initiator
        continue
      }

      try SentrySDK.span?.setData(value: prunable.sizeBytes(), key: prunable.url.path)

      cacheReclaimedBytes += try prunable.sizeBytes()

      try prunable.delete()
    }

    SentrySDK.span?.setMeasurement(name: "gc_disk_reclaimed", value: cacheReclaimedBytes as NSNumber, unit: MeasurementUnitInformation.byte);
  }
}
