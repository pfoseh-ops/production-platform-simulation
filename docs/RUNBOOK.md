# Alert runbook

## First response

1. Confirm the alert is firing and record its labels and start time.
2. Check whether a deployment, node event, or injected simulation aligns with
   the start time.
3. Stabilize service before investigating deeply.
4. Preserve logs and the deployed image SHA.
5. Resolve the alert only after metrics remain healthy for the rule window.

Common commands:

```bash
kubectl -n production-simulation get deploy,pods,hpa,pdb -o wide
kubectl -n production-simulation get events --sort-by=.lastTimestamp
kubectl -n production-simulation logs deploy/production-simulation --since=15m
kubectl -n observability get prometheusrule production-simulation -o yaml
```

## High error rate

Alert: `ProductionSimulationHighErrorRate`

Trigger: more than 10 simulated application errors over two minutes, sustained
for one minute.

```bash
kubectl -n production-simulation logs deploy/production-simulation --since=10m
kubectl -n production-simulation port-forward svc/production-simulation 8080:8080
curl -i http://127.0.0.1:8080/healthz
curl -i http://127.0.0.1:8080/readyz
```

If the error began after deployment, identify and roll back the image:

```bash
kubectl -n production-simulation rollout history deploy/production-simulation
kubectl -n production-simulation rollout undo deploy/production-simulation
kubectl -n production-simulation rollout status deploy/production-simulation
```

For the intentional `errors` simulation, stop the generator and wait for the
Prometheus evaluation window to expire. The endpoint returns errors only for
requests sent directly to `/fail`.

## Deployment unavailable

Alert: `ProductionSimulationUnavailable`

Trigger: fewer than two available replicas for two minutes.

```bash
kubectl -n production-simulation describe deploy production-simulation
kubectl -n production-simulation get pods -o wide
kubectl get nodes
kubectl -n production-simulation get events --sort-by=.lastTimestamp
```

For the intentional unavailable simulation, press Enter in the simulation
terminal. If that process was interrupted, restore three replicas:

```bash
kubectl -n production-simulation scale deploy/production-simulation --replicas=3
kubectl -n production-simulation rollout status deploy/production-simulation
```

If pods are pending, check node capacity, taints, PVC binding, and topology
constraints. If probes fail, inspect the pod logs and endpoint responses.

## Pod restarts

Alert: `ProductionSimulationPodRestarts`

Trigger: more than two container restarts over ten minutes, sustained for one
minute.

```bash
kubectl -n production-simulation get pods
kubectl -n production-simulation describe pods
kubectl -n production-simulation logs deploy/production-simulation --previous
```

Classify the cause as application exit, out-of-memory kill, failed liveness
probe, eviction, or node disruption. Do not increase limits before confirming
actual memory demand and leak behavior.

## Alert delivery verification

Alertmanager posts alerts to the application's `/alerts` endpoint. Confirm
delivery:

```bash
kubectl -n production-simulation logs deploy/production-simulation \
  --since=15m | grep "alert received"
```

If Prometheus shows a firing alert but no delivery:

```bash
kubectl -n observability logs statefulset/alertmanager-prometheus-kube-prometheus-alertmanager
kubectl -n observability get secret alertmanager-prometheus-kube-prometheus-alertmanager-generated \
  -o jsonpath='{.data.alertmanager\\.yaml}' | base64 --decode
```

Never paste the decoded configuration into tickets if external receiver secrets
have been added.
