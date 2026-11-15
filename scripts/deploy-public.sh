#!/usr/bin/env bash
# Déploie la démo publique sur le serveur k3s. Prérequis : ./scripts/install-k3s.sh exécuté,
# DNS du domaine pointé vers le serveur, secrets créés (docs/DEPLOY.md, étape 4).
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}
cd "$(dirname "$0")/.."

if grep -rqE "demo\.example\.com|you@example\.com|/amede-dev/" helm deploy argocd 2>/dev/null; then
  echo "ERREUR : des valeurs d'exemple restent à remplacer (demo.example.com, you@example.com, amede-dev)."
  grep -rnE "demo\.example\.com|you@example\.com|/amede-dev/" helm deploy argocd | head
  exit 1
fi

for ns in observability demo; do kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -; done

for s in grafana-admin; do
  kubectl -n observability get secret "$s" >/dev/null 2>&1 || { echo "ERREUR : secret $s manquant (voir docs/DEPLOY.md)."; exit 1; }
done

echo "→ cert-manager, Prometheus/Grafana, Loki, Fluentd"
helmfile -f helmfile.public.yaml sync

echo "→ Attente du webhook cert-manager puis ClusterIssuer"
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
kubectl apply -f deploy/public/clusterissuer.yaml

echo "→ Configuration : Fluentd, datasources, dashboards, alertes, application de démo"
for d in fluentd grafana/datasources grafana/dashboards alerts/loki apps/demo; do kubectl apply -k "$d"; done
kubectl apply -f alerts/prometheus -f alerts/alertmanager
kubectl apply -f deploy/public/networkpolicy.yaml -f deploy/public/fault-injector.yaml

echo "→ Redémarrage de Fluentd pour charger sa configuration"
kubectl -n observability rollout restart daemonset -l app.kubernetes.io/name=fluentd || true

echo "→ Test de fumée"
kubectl -n demo rollout status deploy/demo-app --timeout=180s
sleep 60
./scripts/smoke-test.sh

echo
echo "Terminé. Grafana : https://$(kubectl -n observability get ingress -o jsonpath='{.items[0].spec.rules[0].host}')"
