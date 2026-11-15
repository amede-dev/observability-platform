# Runbook : TargetDown

## Symptôme
Prometheus ne parvient plus à joindre une cible de scrape (`up == 0`) depuis 2 minutes.

## Impact
Plus de métriques pour cette cible ; les alertes qui en dépendent sont aveugles.

## Vérifications
1. Prometheus > Status > Targets : lire le message d'erreur de la cible.
2. Le pod existe-t-il ? `kubectl -n <ns> get pods -l app=<app>`
3. Le Service et le `ServiceMonitor` ont-ils le même label et le bon nom de port ?
4. Une `NetworkPolicy` bloque-t-elle Prometheus ?
5. Logs du pod : `{namespace="<ns>", app="<app>"}`

## Actions correctives
- Pod arrêté : voir le runbook PodCrashLooping.
- Port ou chemin `/metrics` incorrect : corriger le `ServiceMonitor` dans Git.

## Escalade
Cible critique indisponible plus de 15 minutes : prévenir l'équipe propriétaire.
