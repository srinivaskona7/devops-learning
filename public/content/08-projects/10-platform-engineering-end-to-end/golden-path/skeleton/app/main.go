package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"go.opentelemetry.io/otel/trace"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ─── Configuration ────────────────────────────────────────────────────────────

type Config struct {
	ServiceName    string
	ServiceVersion string
	Port           string
	OTLPEndpoint   string
	LogLevel       string
	SLOTier        string // bronze | silver | gold
}

func configFromEnv() Config {
	return Config{
		ServiceName:    getEnv("SERVICE_NAME", "${{values.name}}"),
		ServiceVersion: getEnv("SERVICE_VERSION", "0.0.1"),
		Port:           getEnv("PORT", "${{values.port}}"),
		OTLPEndpoint:   getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
		LogLevel:       getEnv("LOG_LEVEL", "info"),
		SLOTier:        getEnv("SLO_TIER", "${{values.slo_tier}}"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// ─── Metrics ──────────────────────────────────────────────────────────────────

var (
	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests by method, path, and status code.",
		ConstLabels: prometheus.Labels{
			"service":  "${{values.name}}",
			"slo_tier": "${{values.slo_tier}}",
		},
	}, []string{"method", "path", "status_code"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration in seconds.",
		Buckets: []float64{0.005, 0.010, 0.025, 0.050, 0.100, 0.150, 0.200, 0.300, 0.500, 1.0, 2.0},
		ConstLabels: prometheus.Labels{
			"service":  "${{values.name}}",
			"slo_tier": "${{values.slo_tier}}",
		},
	}, []string{"method", "path"})

	httpRequestsInFlight = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "http_requests_in_flight",
		Help: "Current number of in-flight HTTP requests.",
		ConstLabels: prometheus.Labels{
			"service": "${{values.name}}",
		},
	})

	buildInfo = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Name: "build_info",
		Help: "Build information for the service.",
	}, []string{"version", "go_version", "service", "slo_tier"})
)

// ─── OpenTelemetry Setup ──────────────────────────────────────────────────────

func initTracer(ctx context.Context, cfg Config) (func(context.Context) error, error) {
	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint),
		otlptracegrpc.WithInsecure(), // mTLS handled by Istio sidecar
	)
	if err != nil {
		return nil, fmt.Errorf("create OTLP exporter: %w", err)
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(cfg.ServiceName),
			semconv.ServiceVersion(cfg.ServiceVersion),
			attribute.String("platform.slo_tier", cfg.SLOTier),
			attribute.String("platform.team", "${{values.team}}"),
		),
		resource.WithOS(),
		resource.WithProcess(),
		resource.WithHost(),
	)
	if err != nil {
		return nil, fmt.Errorf("create OTel resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()), // adjust in prod
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return tp.Shutdown, nil
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

type Server struct {
	cfg    Config
	logger *slog.Logger
	tracer trace.Tracer
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"service": s.cfg.ServiceName,
		"version": s.cfg.ServiceVersion,
	})
}

func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	// Add real readiness checks here:
	// - database connection
	// - required config loaded
	// - dependency health
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ready",
	})
}

func (s *Server) handleAPI(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)

	// Add business context to the trace span
	span.SetAttributes(
		attribute.String("service.team", "${{values.team}}"),
		attribute.String("service.slo_tier", s.cfg.SLOTier),
	)

	s.logger.InfoContext(ctx, "handling API request",
		"method", r.Method,
		"path", r.URL.Path,
		"trace_id", span.SpanContext().TraceID().String(),
		"span_id", span.SpanContext().SpanID().String(),
	)

	// TODO: implement service logic here
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"service": s.cfg.ServiceName,
		"message": "Hello from the platform golden-path service",
		"version": s.cfg.ServiceVersion,
	})
}

// ─── Instrumented middleware ───────────────────────────────────────────────────

func (s *Server) instrument(path string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		httpRequestsInFlight.Inc()
		defer httpRequestsInFlight.Dec()

		// Wrap ResponseWriter to capture status code
		rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)

		duration := time.Since(start).Seconds()
		statusCode := fmt.Sprintf("%d", rw.status)

		httpRequestsTotal.WithLabelValues(r.Method, path, statusCode).Inc()
		httpRequestDuration.WithLabelValues(r.Method, path).Observe(duration)
	})
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
}

// ─── Main ──────────────────────────────────────────────────────────────────────

func main() {
	cfg := configFromEnv()

	// Structured logger — JSON output for Loki parsing
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
		AddSource: true,
	}))
	slog.SetDefault(logger)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize OpenTelemetry tracer
	shutdownTracer, err := initTracer(ctx, cfg)
	if err != nil {
		logger.Error("failed to initialize tracer", "error", err)
		os.Exit(1)
	}
	defer func() {
		if err := shutdownTracer(context.Background()); err != nil {
			logger.Error("tracer shutdown error", "error", err)
		}
	}()

	tracer := otel.Tracer(cfg.ServiceName)

	srv := &Server{
		cfg:    cfg,
		logger: logger,
		tracer: tracer,
	}

	// Set build info metric
	buildInfo.WithLabelValues(
		cfg.ServiceVersion,
		runtime.Version(),
		cfg.ServiceName,
		cfg.SLOTier,
	).Set(1)

	// Register routes
	mux := http.NewServeMux()

	// Health probes — not instrumented (avoid noise in metrics)
	mux.HandleFunc("/healthz", srv.handleHealthz)
	mux.HandleFunc("/readyz", srv.handleReadyz)

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Application API — instrumented with OTel + Prometheus
	mux.Handle("/api/",
		srv.instrument("/api",
			otelhttp.NewHandler(
				http.HandlerFunc(srv.handleAPI),
				"api",
			),
		),
	)

	httpServer := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)
		sig := <-sigChan
		logger.Info("received signal, shutting down", "signal", sig)

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()

		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			logger.Error("graceful shutdown failed", "error", err)
		}
		cancel()
	}()

	logger.Info("server starting",
		"service", cfg.ServiceName,
		"version", cfg.ServiceVersion,
		"port", cfg.Port,
		"slo_tier", cfg.SLOTier,
		"otlp_endpoint", cfg.OTLPEndpoint,
	)

	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error("server error", "error", err)
		os.Exit(1)
	}

	logger.Info("server stopped gracefully")
}
