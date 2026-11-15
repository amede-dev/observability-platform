# Scénarios d'injection de pannes

| Test | Commande | Résultat attendu |
| --- | --- | --- |
| T-04 Panne de pod | `for i in $(seq 5); do kubectl -n demo exec deploy/demo-app -- python -c "import urllib.request as u;u.urlopen('http://localhost:8080/crash')" ; sleep 20; done` | Alerte `PodCrashLooping` |
| T-05 Taux d'erreurs | `kubectl -n demo set env deploy/demo-app ERROR_RATE=0.5` | Alerte `HighHTTPErrorRate`, puis résolution après retour à `0.02` |
| T-06 Logs en erreur | Même commande que T-05 | Alerte `HighErrorLogRate` (ruler Loki) |
| T-07 Résilience Fluentd | `kubectl -n observability scale statefulset loki --replicas=0`, attendre 5 min, puis `--replicas=1` | Aucun log perdu, buffer vidé |

Rappel : un changement fait avec `kubectl set env` est annulé par ArgoCD (self-heal) : suspendre
la synchronisation de l'application `demo-app` pendant le test.
