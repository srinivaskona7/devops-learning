"""
Project 05 · Observability Stack — Instrumented FastAPI Service
================================================================
Manual + auto OTel instrumentation: traces, metrics, logs.
Every request carries a trace_id that links the metric label,
the structured log field, and the Tempo span — three pillars, one truth.
"""

import logging
import math
import os
import random
import time

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry import metrics, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.semconv.resource import ResourceAttributes
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# ---------------------------------------------------------------------------
# Resource — shared by all three signal providers
# ---------------------------------------------------------------------------
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")

resource = Resource.create(
    {
        ResourceAttributes.SERVICE_NAME: "obs-demo",
        ResourceAttributes.SERVICE_VERSION: "1.0.0",
        ResourceAttributes.DEPLOYMENT_ENVIRONMENT: os.getenv("ENV", "local"),
    }
)

# ---------------------------------------------------------------------------
# Traces
# ---------------------------------------------------------------------------
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer("obs-demo.tracer")

# ---------------------------------------------------------------------------
# Metrics  (OTel SDK → OTel Collector → Prometheus remote-write)
# ---------------------------------------------------------------------------
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTEL_ENDPOINT, insecure=True),
    export_interval_millis=15_000,
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter("obs-demo.meter")

request_counter = meter.create_counter(
    "http_requests_total",
    description="Total HTTP requests by endpoint and status",
)
request_duration = meter.create_histogram(
    "http_request_duration_seconds",
    description="HTTP request latency in seconds",
    unit="s",
)
error_counter = meter.create_counter(
    "http_errors_total",
    description="Total HTTP 5xx errors",
)

# Prometheus client metrics (scraped directly by ServiceMonitor)
PROM_REQUESTS = Counter(
    "demo_requests_total", "Requests by endpoint", ["endpoint", "status"]
)
PROM_LATENCY = Histogram(
    "demo_request_duration_seconds",
    "Request latency",
    ["endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
)

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
set_logger_provider(logger_provider)

LoggingInstrumentor().instrument(set_logging_format=True)

otel_handler = LoggingHandler(level=logging.DEBUG, logger_provider=logger_provider)
logging.getLogger().addHandler(otel_handler)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] "
    "[trace_id=%(otelTraceID)s span_id=%(otelSpanID)s] %(message)s",
)
logger = logging.getLogger("obs-demo")

# ---------------------------------------------------------------------------
# FastAPI
# ---------------------------------------------------------------------------
app = FastAPI(title="Observability Demo", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

FastAPIInstrumentor.instrument_app(app)


# ---------------------------------------------------------------------------
# Middleware — record metrics for every request
# ---------------------------------------------------------------------------
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response: Response = await call_next(request)
    elapsed = time.perf_counter() - start

    endpoint = request.url.path
    status = str(response.status_code)

    request_counter.add(1, {"endpoint": endpoint, "http.status_code": status})
    request_duration.record(elapsed, {"endpoint": endpoint})
    PROM_REQUESTS.labels(endpoint=endpoint, status=status).inc()
    PROM_LATENCY.labels(endpoint=endpoint).observe(elapsed)

    if response.status_code >= 500:
        error_counter.add(1, {"endpoint": endpoint})

    return response


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus scrape endpoint — consumed by ServiceMonitor."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/fast")
async def fast():
    """Returns immediately. Baseline latency ~1 ms."""
    with tracer.start_as_current_span("fast-handler") as span:
        span.set_attribute("demo.endpoint", "fast")
        logger.info("fast endpoint called")
        return {"endpoint": "fast", "latency_ms": 1}


@app.get("/slow")
async def slow():
    """Simulates a slow DB query. p95 ~2 s."""
    with tracer.start_as_current_span("slow-handler") as span:
        delay = random.uniform(1.5, 2.5)
        span.set_attribute("demo.endpoint", "slow")
        span.set_attribute("demo.simulated_delay_s", round(delay, 3))

        with tracer.start_as_current_span("db-query"):
            logger.info("slow endpoint: simulating DB query", extra={"delay_s": delay})
            time.sleep(delay)

        return {"endpoint": "slow", "delay_s": round(delay, 3)}


@app.get("/flaky")
async def flaky():
    """Fails 30% of requests with HTTP 500. Drives the error-rate panel."""
    with tracer.start_as_current_span("flaky-handler") as span:
        span.set_attribute("demo.endpoint", "flaky")
        if random.random() < 0.30:
            span.set_attribute("error", True)
            span.record_exception(RuntimeError("simulated downstream failure"))
            logger.error("flaky endpoint: simulated failure fired")
            return Response(
                content='{"error": "simulated failure"}',
                status_code=500,
                media_type="application/json",
            )
        logger.info("flaky endpoint: success path")
        return {"endpoint": "flaky", "status": "ok"}


@app.get("/cpu")
async def cpu():
    """Burns CPU for ~200 ms. Drives the saturation panel."""
    with tracer.start_as_current_span("cpu-handler") as span:
        span.set_attribute("demo.endpoint", "cpu")
        start = time.perf_counter()
        # Busy-loop for exactly 200 ms
        while time.perf_counter() - start < 0.2:
            _ = math.sqrt(random.random())
        elapsed = time.perf_counter() - start
        logger.info("cpu endpoint: burn complete", extra={"elapsed_ms": elapsed * 1000})
        return {"endpoint": "cpu", "elapsed_ms": round(elapsed * 1000, 1)}
