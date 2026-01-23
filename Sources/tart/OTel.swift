import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

class OTel {
  let tracerProvider: TracerProviderSdk?
  let tracer: Tracer

  static let shared = OTel()

  init() {
    tracerProvider = Self.initializeTracing()
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "tart", instrumentationVersion: CI.version)
  }

  static func initializeTracing() -> TracerProviderSdk? {
    guard let _ = ProcessInfo.processInfo.environment["TRACEPARENT"] else {
      return nil
    }

    let spanExporter: SpanExporter
    if let endpointRaw = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"],
       let endpoint = URL(string: endpointRaw) {
      spanExporter = OtlpHttpTraceExporter(endpoint: endpoint)
    } else {
      spanExporter = OtlpHttpTraceExporter()
    }
    let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
    let tracerProvider = TracerProviderBuilder().add(spanProcessor: spanProcessor).build()

    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    return tracerProvider
  }

  func flush() {
    OpenTelemetry.instance.contextProvider.activeSpan?.end()

    guard let tracerProvider else {
      // No tracing was initialized, so just ending a span is enough
      return
    }

    tracerProvider.forceFlush()

    // Work around OpenTelemtry not flushing traces after explicitly asking it to do so
    //
    // [1]: https://github.com/open-telemetry/opentelemetry-swift/issues/685
    // [2]: https://github.com/open-telemetry/opentelemetry-swift/issues/555
    Thread.sleep(forTimeInterval: .fromMilliseconds(100))
  }
}
