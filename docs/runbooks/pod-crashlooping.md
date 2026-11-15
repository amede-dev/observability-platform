# Runbook : PodCrashLooping

## Symptôme
Un conteneur a redémarré plus de 3 fois en 15 minutes (alerte critique).

## Impact
Service dégradé ou indisponible pour les utilisateurs du pod concerné.

## Vérifications
1. Dans Grafana, ouvrir le dashboard « Vue d'ensemble du cluster », panneau « Redémarrages de conteneurs ».
2. Logs du pod (LogQL) : `{namespace="<ns>", pod="<pod>"} | json | level=~"error|fatal"`
3. Cause du dernier arrêt : `kubectl -n <ns> describe pod <pod>` (OOMKilled, code de sortie).
4. Mémoire du pod : `container_memory_working_set_bytes{namespace="<ns>", pod="<pod>"}`

## Actions correctives
- OOMKilled : augmenter la limite mémoire dans Git (PR), laisser ArgoCD synchroniser.
- Erreur applicative : revenir à la version précédente (`git revert`), analyser les logs.
- Dépendance indisponible : vérifier le service amont.

## Escalade
Pas de résolution sous 30 minutes : prévenir l'équipe propriétaire du service.
