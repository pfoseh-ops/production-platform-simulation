package main

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type failingRoundTripper struct{}

func (failingRoundTripper) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, errors.New("connection failed")
}

func TestHealth(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	recorder := httptest.NewRecorder()
	routes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", recorder.Code)
	}
}

func TestHealthCheckReturnsSuccessForHTTP200(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	if err := healthCheck(server.Client(), server.URL); err != nil {
		t.Fatalf("expected successful health check, got %v", err)
	}
}

func TestHealthCheckReturnsErrorForNon200(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "unavailable", http.StatusServiceUnavailable)
	}))
	defer server.Close()

	if err := healthCheck(server.Client(), server.URL); err == nil {
		t.Fatal("expected non-200 response to fail the health check")
	}
}

func TestHealthCheckReturnsErrorForRequestFailure(t *testing.T) {
	client := &http.Client{Transport: failingRoundTripper{}}
	if err := healthCheck(client, "http://127.0.0.1:8080/healthz"); err == nil {
		t.Fatal("expected request failure to fail the health check")
	}
}

func TestFailureDefaultsTo500(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/fail", nil)
	recorder := httptest.NewRecorder()
	routes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", recorder.Code)
	}
}

func TestMetrics(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	recorder := httptest.NewRecorder()
	routes().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "app_requests_total") {
		t.Fatal("expected application metrics")
	}
}
