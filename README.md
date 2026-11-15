# Plateforme d'observabilité Cloud-Native (Observability-as-Code)

Prometheus (métriques) + Fluentd/Loki (logs) + Grafana (visualisation, corrélation) + Alertmanager,
déployés et configurés entièrement depuis Git.

## Démarrage rapide (local, kind)

Prérequis : `docker`, `kind`, `kubectl`, `helm`, `helmfile`, `terraform`, `promtool` (pour `make test`).

```bash
make cluster     # cluster kind + namespaces (Terraform)
make deploy      # construit l'image Fluentd locale puis installe toute la stack
make config      # Fluentd conf, datasources, dashboards, alertes, application de démo
make smoke       # vérification : cibles up, logs dans Loki, Watchdog actif
# Le nom du Service Grafana varie selon la version du chart.
GRAFANA_SVC=$(kubectl -n observability get svc \
  -l app.kubernetes.io/name=grafana \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n observability port-forward "svc/${GRAFANA_SVC}" 3000:80   # http://localhost:3000
```

## À faire avant le premier déploiement

1. **Image Fluentd** : en local, `make deploy` construit et charge automatiquement
   `fluentd-loki:1.0.0` dans Kind. Pour la démo publique, construire et publier
   `fluentd/Dockerfile`, puis remplacer `amede-dev` dans les valeurs publiques.
2. **Versions** : figer les versions de charts dans `helmfile.yaml` (`helm search repo <chart> --versions`).
3. **Secrets** : remplacer `grafana.adminPassword` et créer le secret `alertmanager-slack`
   (SOPS ou Sealed Secrets ; jamais en clair dans Git).
4. **GitOps** : remplacer `amede-dev` dans `argocd/` et `helm/fluentd/values.yaml` par votre dépôt.
5. **Fluentd** : le ConfigMap `fluentd-main` vient de `fluentd/kustomization.yaml` ; vérifier que la
   chart Fluentd choisie monte bien `/etc/fluent/fluent.conf` (voir `helm/fluentd/values.yaml`).

Les valeurs Helm sont écrites pour les versions récentes des charts : lancer `helmfile lint` /
`helmfile template` après avoir figé les versions, et ajuster si une clé a changé.

## Structure

| Dossier | Contenu |
| --- | --- |
| `terraform/` | Namespaces (cluster fourni par kind / cloud) |
| `helmfile.yaml`, `helm/` | Releases et valeurs : kube-prometheus-stack, Loki, Fluentd |
| `fluentd/` | `fluent.conf`, Dockerfile, ConfigMap (kustomize) |
| `grafana/datasources/` | Datasource Loki (Prometheus fournie par la chart) |
| `grafana/dashboards/` | 4 dashboards JSON chargés par le sidecar |
| `alerts/prometheus/` | `PrometheusRule` : alertes plateforme et application, recording rules |
| `alerts/loki/` | Règles LogQL du ruler Loki |
| `alerts/alertmanager/` | Routage, inhibition, contact points |
| `alerts/tests/` | Tests unitaires `promtool` |
| `apps/demo/` | Application de démonstration (métriques + logs JSON) |
| `argocd/` | Application racine et applications enfants (GitOps) |
| `scripts/`, `tests/` | Test de fumée, extraction des règles, scénarios de pannes |
| `docs/runbooks/` | Runbooks des alertes critiques |
| `.github/workflows/ci.yml` | Lint, règles, manifestes, sécurité, test d'intégration kind |

## Corrélation métriques ↔ logs

Les labels `namespace`, `pod`, `app` sont identiques dans Prometheus et Loki. Dans le dashboard
« Méthode RED par service », le lien « Voir les logs » d'un graphique ouvre Explore (Loki) sur le
même service et la même période, et un panneau de logs partage les variables des graphiques.

## Scénarios de démonstration

Voir `tests/fault-injection.md` (panne de pod, pic d'erreurs, indisponibilité de Loki).
