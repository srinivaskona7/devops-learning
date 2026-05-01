# OTel Instrumentation Snippets

All examples assume an OTel Collector reachable at `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`.

## Python (FastAPI)

Install:
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp \
            opentelemetry-instrumentation-fastapi
opentelemetry-bootstrap -a install
```

Run with **zero code changes**:
```bash
OTEL_SERVICE_NAME=checkout-svc \
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317 \
OTEL_RESOURCE_ATTRIBUTES=service.version=1.4.2,deployment.environment=prod \
opentelemetry-instrument uvicorn app:app
```

Manual span:
```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("compute_total") as span:
    span.set_attribute("cart.item_count", len(items))
    total = sum(i.price for i in items)
    span.set_attribute("cart.total", total)
```

## Go

```go
import (
  "go.opentelemetry.io/otel"
  "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
  sdktrace "go.opentelemetry.io/otel/sdk/trace"
  "go.opentelemetry.io/otel/sdk/resource"
  semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func initTracer(ctx context.Context) func() {
  exp, _ := otlptracegrpc.New(ctx,
    otlptracegrpc.WithEndpoint("otel-collector:4317"),
    otlptracegrpc.WithInsecure(),
  )
  res, _ := resource.New(ctx,
    resource.WithAttributes(
      semconv.ServiceName("checkout-svc"),
      semconv.ServiceVersion("1.4.2"),
    ),
  )
  tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exp),
    sdktrace.WithResource(res),
  )
  otel.SetTracerProvider(tp)
  return func() { _ = tp.Shutdown(ctx) }
}

// Use it
tracer := otel.Tracer("checkout")
ctx, span := tracer.Start(ctx, "compute_total")
defer span.End()
```

## Node.js (Express)

```bash
npm i @opentelemetry/api @opentelemetry/sdk-node \
      @opentelemetry/auto-instrumentations-node \
      @opentelemetry/exporter-trace-otlp-grpc
```

`tracing.js` (require this **before** your app):
```js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { resourceFromAttributes } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: 'checkout-svc',
    [ATTR_SERVICE_VERSION]: '1.4.2',
  }),
  traceExporter: new OTLPTraceExporter({ url: 'http://otel-collector:4317' }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

Run: `node -r ./tracing.js server.js`

## Correlating logs to traces

In every log line, include the current trace and span IDs:

```python
from opentelemetry import trace
ctx = trace.get_current_span().get_span_context()
logger.info("processed", extra={"trace_id": format(ctx.trace_id, "032x"),
                                 "span_id":  format(ctx.span_id,  "016x")})
```

Loki's `derivedFields` (see `03-grafana/provisioning/datasources.yaml`) will then auto-link log lines → traces in Grafana.
