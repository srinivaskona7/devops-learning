// main.go — Progressive delivery demo service
// Supports v1 (healthy) and v2 (bad-weight mode to trigger automatic rollback).
//
// Environment variables:
//   VERSION       string  — reported in /api response (default "v1")
//   BAD_WEIGHT    float64 — fraction of /api requests that return HTTP 500 (0.0–1.0)
//   PORT          string  — listen port (default "8080")
package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ─── metrics ────────────────────────────────────────────────────────────────

var (
	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests partitioned by status code and path.",
	}, []string{"code", "path"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request latency.",
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5},
	}, []string{"path"})

	buildInfo = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Name: "app_build_info",
		Help: "Static build / version info.",
	}, []string{"version"})
)

// ─── config ─────────────────────────────────────────────────────────────────

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func badWeight() float64 {
	s := envOr("BAD_WEIGHT", "0.0")
	f, err := strconv.ParseFloat(s, 64)
	if err != nil || f < 0 || f > 1 {
		return 0.0
	}
	return f
}

// ─── handlers ───────────────────────────────────────────────────────────────

type apiResponse struct {
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
	Hostname  string `json:"hostname"`
	Message   string `json:"message"`
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	defer func() {
		httpRequestDuration.WithLabelValues("/healthz").Observe(time.Since(start).Seconds())
		httpRequestsTotal.WithLabelValues("200", "/healthz").Inc()
	}()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	version := envOr("VERSION", "v1")
	hostname, _ := os.Hostname()

	// Inject fault when BAD_WEIGHT > 0 — simulates a bad canary.
	if badWeight() > 0 && rand.Float64() < badWeight() { //nolint:gosec
		httpRequestDuration.WithLabelValues("/api").Observe(time.Since(start).Seconds())
		httpRequestsTotal.WithLabelValues("500", "/api").Inc()
		http.Error(w, `{"error":"injected fault — bad canary"}`, http.StatusInternalServerError)
		return
	}

	// Simulate realistic latency: v1 ~20ms, v2 ~25ms.
	baseLatency := 20 * time.Millisecond
	if version == "v2" {
		baseLatency = 25 * time.Millisecond
	}
	jitter := time.Duration(rand.Intn(15)) * time.Millisecond //nolint:gosec
	time.Sleep(baseLatency + jitter)

	httpRequestDuration.WithLabelValues("/api").Observe(time.Since(start).Seconds())
	httpRequestsTotal.WithLabelValues("200", "/api").Inc()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Version", version)
	_ = json.NewEncoder(w).Encode(apiResponse{
		Version:   version,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Hostname:  hostname,
		Message:   "Hello from progressive delivery demo",
	})
}

// ─── main ────────────────────────────────────────────────────────────────────

func main() {
	version := envOr("VERSION", "v1")
	port := envOr("PORT", "8080")

	// Expose version as a gauge so Grafana can join on it.
	buildInfo.WithLabelValues(version).Set(1)

	rand.Seed(time.Now().UnixNano()) //nolint:staticcheck

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/api", apiHandler)
	mux.Handle("/metrics", promhttp.Handler())

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Printf("starting version=%s port=%s bad_weight=%.2f", version, port, badWeight())
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
