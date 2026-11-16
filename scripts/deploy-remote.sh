#!/usr/bin/env bash
# Déploiement distant k3s sans domaine ni certificat TLS.
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
cd "$(dirname "$0")/.."

command -v kubectl >/dev/null || { echo "kubectl est introuvable"; exit 1; }
command -v helmfile >/dev/null || { echo "helmfile est introuvable"; exit 1; }

for ns in observability demo; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

if ! kubectl -n observability get secret grafana-admin >/dev/null 2>&1; then
  echo "ERREUR : le secret observability/grafana-admin est manquant."
  echo "Créez-le avant de relancer :"
  echo '  kubectl -n observability create secret generic grafana-admin \'
  echo '    --from-literal=admin-user=admin \'
  echo '    --from-literal=admin-password="$(openssl rand -base64 24)"'
  exit 1
fi

echo "→ Déploiement k3s sans domaine"
helmfile -f helmfile.remote.yaml sync

echo "→ Configuration Fluentd, dashboards, alertes et application de démo"
for d in fluentd grafana/datasources grafana/dashboards alerts/loki apps/demo; do
  kubectl apply -k "$d"
done
kubectl apply -f alerts/prometheus -f alerts/alertmanager
kubectl apply -f deploy/public/networkpolicy.yaml -f deploy/public/fault-injector.yaml

echo "→ Attente du déploiement Fluentd"
kubectl -n observability rollout status daemonset/fluentd --timeout=180s
kubectl -n demo rollout status deployment/demo-app --timeout=180s

echo "→ Test de fumée"
./scripts/smoke-test.sh

echo
echo "Déploiement terminé."
echo "Grafana : http://IP_DU_SERVEUR:30080"
echo "Nœuds :"
kubectl get nodes -o wide
