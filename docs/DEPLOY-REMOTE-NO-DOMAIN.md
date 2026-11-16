# Déploiement distant sans domaine ni carte bancaire

Cette variante installe toute la plateforme sur un serveur Linux avec k3s, sans achat de domaine.
Grafana est accessible par le NodePort `30080` :

```text
http://IP_DU_SERVEUR:30080
```

## Prérequis du serveur

- Ubuntu 22.04/24.04 ou Debian ;
- 2 vCPU et 4 Go de RAM minimum ;
- 40 Go de stockage recommandés ;
- accès SSH ;
- port TCP `22` pour SSH et `30080` pour Grafana.

Le serveur peut être fourni par une école, une entreprise ou une connaissance. Render et Vercel ne
peuvent pas remplacer ce serveur : ils ne permettent pas d'installer et d'administrer un cluster k3s.

## Installation

Sur le serveur :

```bash
git clone https://github.com/amede-dev/observability-platform.git
cd observability-platform
sudo ./scripts/install-k3s.sh
```

Créer le mot de passe Grafana hors Git :

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"
```

Déployer :

```bash
sudo ./scripts/deploy-remote.sh
```

Depuis Windows, ouvrir `http://IP_DU_SERVEUR:30080` dans un navigateur.

## Limites

Cette variante utilise HTTP et un NodePort. Elle est adaptée à une démonstration ou à un projet
personnel, pas à une exposition publique de production. Pour la production, il faudra ajouter un
domaine, HTTPS, une authentification renforcée et des sauvegardes.
