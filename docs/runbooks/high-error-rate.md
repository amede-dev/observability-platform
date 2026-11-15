# Runbook : HighHTTPErrorRate

## Symptôme
Plus de 5 % des requêtes HTTP répondent en 5xx pendant 5 minutes (alerte critique).

## Impact
Une part notable des utilisateurs reçoit des erreurs.

## Vérifications
1. Dashboard « Méthode RED par service » : repérer le début du pic d'erreurs.
2. Cliquer « Voir les logs » sur le graphique : le pod et la plage de temps sont conservés.
3. LogQL : `{namespace="<ns>", app="<app>"} | json | level="error"`
4. Un déploiement récent coïncide-t-il avec le pic ? Comparer avec l'historique Git / ArgoCD.
5. Latence et CPU : la saturation précède souvent les erreurs.

## Actions correctives
- Régression après déploiement : revenir à la version précédente.
- Saturation : augmenter les réplicas ou les ressources.
- Dépendance en panne : activer le mode dégradé, contacter l'équipe concernée.

## Escalade
Erreurs toujours supérieures à 5 % après 15 minutes : escalade vers l'astreinte niveau 2.
