# Déploiement en ligne (démo publique)

Résultat : Grafana accessible en HTTPS, en lecture seule pour les visiteurs, alimenté par une
application de démonstration qui génère métriques, logs et pannes simulées.

## Prérequis

- Un serveur Linux (Ubuntu 22.04 ou 24.04) avec au minimum 2 vCPU et 4 Go de RAM
  (4 vCPU et 8 Go recommandés), 40 Go de disque, une IP publique.
- Un nom de domaine : enregistrement DNS **A** `demo.mondomaine.com` vers l'IP du serveur.
- Un compte GitHub (le dépôt, et l'image Fluentd sur ghcr.io).
- Pare-feu du serveur : ouvrir 22, 80, 443 uniquement.

## Étape 1 : personnaliser le dépôt (sur votre poste)

```bash
# remplacer les valeurs d'exemple
grep -rl "amede-dev" . | xargs sed -i 's/amede-dev/VOTRE_PSEUDO_GITHUB/g'
grep -rl "demo.example.com" . | xargs sed -i 's/demo.example.com/demo.mondomaine.com/g'
sed -i 's/you@example.com/votre@email.com/' deploy/public/clusterissuer.yaml
```

Puis figer les versions de charts dans `helmfile.public.yaml` (`helm search repo <chart> --versions`).

## Étape 2 : publier l'image Fluentd

Pousser le dépôt sur GitHub : le workflow `fluentd-image` construit et publie
`ghcr.io/VOTRE_PSEUDO/fluentd-loki:1.0.0`. Dans GitHub, rendre le package **public**
(Package settings > Change visibility), sinon le cluster ne pourra pas le télécharger.

## Étape 3 : installer k3s sur le serveur

```bash
ssh utilisateur@IP_DU_SERVEUR
git clone https://github.com/VOTRE_PSEUDO/observability-platform.git && cd observability-platform
sudo ./scripts/install-k3s.sh
```

## Étape 4 : créer les secrets (hors Git)

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl create namespace observability
kubectl -n observability create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"
```

Notez le mot de passe (`kubectl -n observability get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d`).
Pas de webhook Slack dans la démo publique : les alertes restent visibles dans Grafana.

## Étape 5 : déployer

```bash
make deploy-public
```

Le script vérifie qu'il ne reste plus de valeurs d'exemple, déploie la stack, attend cert-manager,
applique la configuration et lance le test de fumée. Le certificat HTTPS peut demander 1 à 2 minutes.

## Étape 6 : vérifier

- https://demo.mondomaine.com s'ouvre sans connexion (Viewer). Connexion admin : bouton « Sign in ».
- Dossiers « Plateforme » et « Applications » avec 4 dashboards ; le panneau de logs du dashboard
  « Méthode RED par service » affiche des lignes (preuve que Fluentd et Loki fonctionnent).
- Toutes les 2 heures, un pic d'erreurs simulé déclenche l'alerte `HighHTTPErrorRate`.
  Pour le provoquer tout de suite :
  `kubectl -n demo create job --from=cronjob/fault-injector test-panne`

## Dépannage rapide

| Symptôme | Vérification |
| --- | --- |
| Pas de HTTPS | `kubectl describe certificate -A` ; DNS correct ? ports 80/443 ouverts ? |
| Pod en `ImagePullBackOff` (Fluentd) | Image publiée ? package public ? `amede-dev` remplacé ? |
| Pas de logs dans Grafana | `kubectl -n observability logs ds/fluentd` ; `make smoke` |
| Pod `Pending` | Mémoire insuffisante : `kubectl describe pod` ; serveur trop petit |
| Cible Prometheus `down` | Prometheus > Status > Targets, message d'erreur |

## Lien dans le portfolio

Bouton « Live demo » vers `https://demo.mondomaine.com`, et lien « Code » vers le dépôt.
Gardez aussi une vidéo de secours dans le README, au cas où le serveur serait éteint.

## Sécurité de la démo

Seul Grafana est exposé ; le rôle visiteur est Viewer ; les dashboards sont en lecture seule ;
Prometheus, Alertmanager et Loki n'ont aucun Ingress ; le mot de passe admin est dans un Secret ;
le port 6443 de Kubernetes reste fermé. Appliquez régulièrement les mises à jour du serveur.
