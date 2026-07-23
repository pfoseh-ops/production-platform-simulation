package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"
)

var (
	requestsTotal atomic.Uint64
	errorsTotal   atomic.Uint64
	startedAt     = time.Now()
)

type response struct {
	Service string `json:"service"`
	Status  string `json:"status"`
	Version string `json:"version"`
}

func main() {
	port := env("PORT", "8080")
	mux := routes()
	server := &http.Server{
		Addr:              ":" + port,
		Handler:           instrument(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("production-simulation-api listening on :%s", port)
	log.Fatal(server.ListenAndServe())
}

func routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/healthz", handleHealth)
	mux.HandleFunc("/readyz", handleReady)
	mux.HandleFunc("/fail", handleFailure)
	mux.HandleFunc("/alerts", handleAlert)
	mux.HandleFunc("/metrics", handleMetrics)
	return mux
}

func handleRoot(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, response{
		Service: "production-platform-simulation",
		Status:  "ok",
		Version: env("APP_VERSION", "dev"),
	})
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func handleReady(w http.ResponseWriter, _ *http.Request) {
	if env("FORCE_NOT_READY", "false") == "true" {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready\n"))
}

func handleFailure(w http.ResponseWriter, r *http.Request) {
	status, err := strconv.Atoi(r.URL.Query().Get("status"))
	if err != nil || status < 400 || status > 599 {
		status = http.StatusInternalServerError
	}
	errorsTotal.Add(1)
	http.Error(w, http.StatusText(status), status)
}

func handleAlert(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var payload any
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&payload); err != nil {
		http.Error(w, "invalid alert payload", http.StatusBadRequest)
		return
	}
	log.Printf("alert received: %v", payload)
	w.WriteHeader(http.StatusAccepted)
}

func handleMetrics(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	_, _ = fmt.Fprintf(w, "# HELP app_requests_total Total HTTP requests.\n")
	_, _ = fmt.Fprintf(w, "# TYPE app_requests_total counter\n")
	_, _ = fmt.Fprintf(w, "app_requests_total %d\n", requestsTotal.Load())
	_, _ = fmt.Fprintf(w, "# HELP app_errors_total Total simulated application errors.\n")
	_, _ = fmt.Fprintf(w, "# TYPE app_errors_total counter\n")
	_, _ = fmt.Fprintf(w, "app_errors_total %d\n", errorsTotal.Load())
	_, _ = fmt.Fprintf(w, "# HELP app_uptime_seconds Process uptime in seconds.\n")
	_, _ = fmt.Fprintf(w, "# TYPE app_uptime_seconds gauge\n")
	_, _ = fmt.Fprintf(w, "app_uptime_seconds %.0f\n", time.Since(startedAt).Seconds())
}

func instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestsTotal.Add(1)
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
