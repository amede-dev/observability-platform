#!/usr/bin/env bash
# À exécuter UNE FOIS sur le serveur (Ubuntu/Debian), en root : installe k3s, helm, helm-diff, helmfile.
# Usage : sudo ./scripts/install-k3s.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Exécuter avec sudo."; exit 1; }

echo "→ Installation de k3s (Traefik et stockage local inclus)"
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -q KUBECONFIG /etc/environment || echo 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /etc/environment

echo "→ Installation de helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "→ Installation du plugin helm-diff (requis par helmfile)"
helm plugin install https://github.com/databus23/helm-diff || true

echo "→ Installation de helmfile (dernière version)"
TAG=$(curl -fsSL https://api.github.com/repos/helmfile/helmfile/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
VER=${TAG#v}
curl -fsSL "https://github.com/helmfile/helmfile/releases/download/${TAG}/helmfile_${VER}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin helmfile

echo "→ Attente que le nœud soit prêt"
kubectl wait --for=condition=Ready node --all --timeout=180s

cat <<'EOF'

k3s est prêt. Ouvrir les ports 80 et 443 (et 22) dans le pare-feu du serveur ; ne PAS ouvrir 6443 ni 9090.
Étape suivante : ./scripts/deploy-public.sh
EOF
