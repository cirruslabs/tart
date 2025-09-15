import Foundation

#if canImport(OpenTelemetryApi)
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterGrpc
import OpenTelemetryProtocolExporterHttp
import GRPC
import NIO
#endif

enum TelemetrySpanStatus {
  case cancelled
}

final class TelemetrySpan {
  #if canImport(OpenTelemetryApi)
  private let span: Span?
  #else
  private let span: Any? = nil
  #endif

  init(_ span: Any?) {
    #if canImport(OpenTelemetryApi)
    self.span = span as? Span
    #endif
  }

  func finish(status: TelemetrySpanStatus? = nil) {
    #if canImport(OpenTelemetryApi)
    if let span = span {
      if let status = status {
        switch status {
        case .cancelled:
          span.status = .error(description: "cancelled")
        }
      }
      span.end()
      if Telemetry.currentSpan === span {
        Telemetry.currentSpan = nil
      }
    }
    #endif
  }
}

enum Telemetry {
  #if canImport(OpenTelemetryApi)
  static var tracer: Tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "tart", instrumentationVersion: CI.version)
  static var currentSpan: Span?
  private static var eventLoopGroup: EventLoopGroup?
  private static var providerSdk: TracerProviderSdk?
  #else
  static var currentSpan: Any?
  #endif

  // Configure OpenTelemetry when OTEL_EXPORTER_OTLP_ENDPOINT is set.
  static func bootstrapFromEnv() {
    guard let endpoint = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_ENDPOINT"], !endpoint.isEmpty else {
      return
    }

    #if canImport(OpenTelemetryApi)
    let resource = buildResource()

    // Build exporter configuration
    let headerList = parseHeaders(ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_HEADERS"]) // [(k,v)]

    // Build exporter based on endpoint scheme
    var exporter: SpanExporter
    if endpoint.lowercased().hasPrefix("http://") || endpoint.lowercased().hasPrefix("https://") {
      let url = URL(string: endpoint)!
      let config = OtlpConfiguration(timeout: 10, headers: headerList, exportAsJson: false)
      exporter = OtlpHttpTraceExporter(endpoint: url, config: config, envVarHeaders: nil)
    } else {
      // gRPC: parse host[:port]
      let parts = endpoint.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
      let host = String(parts.first!)
      let port = parts.count > 1 ? Int(parts[1]) ?? 4317 : 4317
      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      eventLoopGroup = group
      let channel = ClientConnection.insecure(group: group).connect(host: host, port: port)
      let config = OtlpConfiguration(timeout: 10, headers: headerList, exportAsJson: false)
      exporter = OtlpTraceExporter(channel: channel, config: config, envVarHeaders: nil)
    }

    let spanProcessor = BatchSpanProcessor(spanExporter: exporter)
    let provider = TracerProviderBuilder()
      .add(spanProcessor: spanProcessor)
      .with(resource: resource)
      .build()

    providerSdk = provider
    OpenTelemetry.registerTracerProvider(tracerProvider: provider)
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "tart", instrumentationVersion: CI.version)
    #endif
  }

  // Flush spans quickly on shutdown
  static func flush() {
    #if canImport(OpenTelemetryApi)
    providerSdk?.forceFlush(timeout: 5)
    if let group = eventLoopGroup {
      try? group.syncShutdownGracefully()
      eventLoopGroup = nil
    }
    #endif
  }

  static func startTransaction(name: String, operation: String? = nil, bindToScope: Bool = false) -> TelemetrySpan {
    #if canImport(OpenTelemetryApi)
    let builder = tracer.spanBuilder(spanName: name)
    if let op = operation {
      builder.setSpanKind(spanKind: .internal)
      builder.setAttribute(key: "operation", value: op)
    }
    let span = builder.startSpan()
    if bindToScope {
      currentSpan = span
    }
    return TelemetrySpan(span)
    #else
    return TelemetrySpan(nil)
    #endif
  }

  static func recordError(_ error: Error) {
    #if canImport(OpenTelemetryApi)
    let span = currentSpan ?? tracer.spanBuilder(spanName: "error").startSpan()
    span.recordException(error)
    span.status = .error(description: String(describing: error))
    if currentSpan == nil {
      span.end()
    }
    #endif
  }

  static func addEvent(_ name: String, attributes: [String: AttributeValue] = [:]) {
    #if canImport(OpenTelemetryApi)
    currentSpan?.addEvent(name: name, attributes: attributes)
    #endif
  }

  static func setAttribute(_ key: String, _ value: AttributeValue) {
    #if canImport(OpenTelemetryApi)
    currentSpan?.setAttribute(key: key, value: value)
    #endif
  }

  // Build a Resource with service + environment tags
  private static func buildResource() -> Resource {
    #if canImport(OpenTelemetryApi)
    var attributes: [String: AttributeValue] = [
      "service.name": .string("tart"),
      "service.version": .string(CI.version),
      "process.command_args": AttributeValue(ProcessInfo.processInfo.arguments)
    ]

    // Migrate Sentry tags to resource attributes if present
    if let tags = ProcessInfo.processInfo.environment["CIRRUS_SENTRY_TAGS"] {
      for (k, v) in parseTags(tags) {
        attributes[k] = .string(v)
      }
    }

    return Resource(attributes: attributes)
    #else
    return Resource()
    #endif
  }

  private static func parseTags(_ raw: String) -> [(String, String)] {
    raw.split(separator: ",").compactMap { pair in
      let parts = pair.split(separator: "=", maxSplits: 1)
      guard parts.count == 2 else { return nil }
      return (String(parts[0]), String(parts[1]))
    }
  }

  private static func parseHeaders(_ raw: String?) -> [(String, String)] {
    guard let raw = raw else { return [] }
    var result: [(String, String)] = []
    for part in raw.split(separator: ",") {
      let kv = part.split(separator: "=", maxSplits: 1)
      guard kv.count == 2 else { continue }
      result.append((String(kv[0]), String(kv[1])))
    }
    return result
  }
}
