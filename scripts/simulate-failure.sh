#!/usr/bin/env bash
set -euo pipefail

namespace=production-simulation
deployment=production-simulation
mode=${1:-errors}

cleanup() {
  if [[ -n "${port_forward_pid:-}" ]]; then
    kill "${port_forward_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

case "${mode}" in
  errors)
    kubectl -n "${namespace}" port-forward "svc/${deployment}" 18080:8080 >/tmp/production-simulation-port-forward.log 2>&1 &
    port_forward_pid=$!
    sleep 2
    for _ in $(seq 1 20); do
      curl --fail-with-body --silent --output /dev/null "http://127.0.0.1:18080/fail?status=500" || true
    done
    echo "Injected 20 errors. The high-error-rate alert should fire after its evaluation window."
    ;;
  unavailable)
    original_replicas=$(kubectl -n "${namespace}" get deployment "${deployment}" -o jsonpath='{.spec.replicas}')
    kubectl -n "${namespace}" scale deployment "${deployment}" --replicas=0
    echo "Deployment scaled to zero. Press Enter to restore ${original_replicas} replicas."
    read -r
    kubectl -n "${namespace}" scale deployment "${deployment}" --replicas="${original_replicas}"
    ;;
  restart)
    for _ in 1 2 3; do
      kubectl -n "${namespace}" delete pod -l app.kubernetes.io/name=production-simulation --wait=false
      sleep 10
    done
    echo "Restart sequence completed."
    ;;
  *)
    echo "usage: $0 [errors|unavailable|restart]" >&2
    exit 1
    ;;
esac
