#!/usr/bin/env bash
# Test de fumée post-déploiement : cibles up, logs dans Loki, alerte Watchdog active.
set -euo pipefail
NS=observability
pf() { kubectl -n "$NS" port-forward "svc/$1" "$2" >/dev/null 2>&1 & echo $!; }
service_by_label() {
  kubectl -n "$NS" get svc -l "$1" -o jsonpath='{.items[0].metadata.name}'
}

# `fullnameOverride: kps` fixe le Service Prometheus ; le Service Grafana,
# lui, est fourni par la sous-chart et garde un nom différent.
PROMETHEUS_SVC=kps-prometheus
LOKI_SVC=$(service_by_label 'app.kubernetes.io/name=loki,app.kubernetes.io/component=gateway')
test -n "$PROMETHEUS_SVC" || { echo "ÉCHEC : Service Prometheus introuvable"; exit 1; }
test -n "$LOKI_SVC" || { echo "ÉCHEC : Service Loki introuvable"; exit 1; }

P1=$(pf "$PROMETHEUS_SVC" 9090:9090); L1=$(pf "$LOKI_SVC" 3100:80)
trap 'kill $P1 $L1 2>/dev/null || true' EXIT
sleep 5

echo "→ Cibles Prometheus à 0 (down) :"
DOWN=$(curl -sf 'http://localhost:9090/api/v1/query?query=count(up==0)' | python3 -c "import sys,json;r=json.load(sys.stdin)['data']['result'];print(r[0]['value'][1] if r else 0)")
echo "  $DOWN"

echo "→ Watchdog actif :"
curl -sf 'http://localhost:9090/api/v1/query?query=ALERTS{alertname="Watchdog"}' | grep -q Watchdog && echo "  ok"

echo "→ Logs reçus par Loki (5 dernières minutes) :"
curl -sf -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query=sum(count_over_time({namespace="demo"}[5m]))' | grep -q '"result":\[{' && echo "  ok"

[ "$DOWN" = "0" ] && echo "SMOKE TEST OK" || { echo "ÉCHEC : $DOWN cible(s) down"; exit 1; }
