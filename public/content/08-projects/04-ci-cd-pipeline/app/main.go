package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

// HelloResponse is the JSON shape returned by /api/hello.
type HelloResponse struct {
	Message   string    `json:"message"`
	Hostname  string    `json:"hostname"`
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version"`
}

// HealthResponse is returned by /healthz and /ready.
type HealthResponse struct {
	Status string `json:"status"`
}

var version = "dev" // overridden at build time via -ldflags

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(HealthResponse{Status: "ok"})
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(HealthResponse{Status: "ready"})
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	resp := HelloResponse{
		Message:   "Hello from the CI/CD pipeline demo app",
		Hostname:  hostname,
		Timestamp: time.Now().UTC(),
		Version:   version,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("error encoding response: %v", err)
	}
}

func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/ready", readyHandler)
	mux.HandleFunc("/api/hello", helloHandler)
	return mux
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := newMux()
	addr := fmt.Sprintf(":%s", port)
	log.Printf("starting server version=%s addr=%s", version, addr)

	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}

	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
