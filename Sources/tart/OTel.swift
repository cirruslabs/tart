import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

class OTel {
  let spanExporter: SpanExporter
  let spanProcessor: SpanProcessor
  let tracerProvider: TracerProviderSdk
  let tracer: Tracer

  static let shared = OTel()

  init() {
    if let endpointRaw = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"],
       let endpoint = URL(string: endpointRaw) {
      spanExporter = OtlpHttpTraceExporter(endpoint: endpoint)
    } else {
      spanExporter = OtlpHttpTraceExporter()
    }
    spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
    tracerProvider = TracerProviderBuilder().add(spanProcessor: spanProcessor).build()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "tart", instrumentationVersion: CI.version)
  }

  func flush() {
    OpenTelemetry.instance.contextProvider.activeSpan?.end()

    tracerProvider.forceFlush()

    // Work around OpenTelemtry not flushing traces after explicitly asking it to do so
    //
    // [1]: https://github.com/open-telemetry/opentelemetry-swift/issues/685
    // [2]: https://github.com/open-telemetry/opentelemetry-swift/issues/555
    Thread.sleep(forTimeInterval: .fromMilliseconds(100))
  }
}
