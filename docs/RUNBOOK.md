# Runbook — Déploiement, rollback, restauration, incidents

Document issu des Phases 3 et 4 du plan de remédiation (`docs/audit-J1-equipe-entrante.md`), en
réponse directe aux causes racines listées dans `docs/incident-aout-2024.md` : pas de backup
récent, pas de procédure de rollback documentée, aucune alerte automatique.

## Déploiement normal

Le seul chemin de déploiement supporté est la CI (`.github/workflows/deploy.yml`), déclenchée sur
`push`/`pull_request` vers `main` :

1. `build` : installe et build le frontend.
2. `test` / `test-frontend` : exécute les suites de tests (`auth`, `paie`, `conges`, frontend).
3. `security` : `npm audit --omit=dev --audit-level=high` sur chaque service — bloque sur
   vulnérabilité high/critical.
4. `staging` : déploiement SSH (clé) + smoke test `/health`, seulement sur push à `main`.
5. `prod` : nécessite que `staging` ait réussi, déploiement SSH + health-check, **rollback
   automatique si le health-check échoue** (section suivante).

Ne jamais déployer manuellement en contournant la CI (c'est exactement ce qui a causé l'incident
du 14/15 août 2024 : une migration lancée à la main, un soir, sans passer par aucun gate). Si un
déploiement manuel est vraiment nécessaire, utiliser `scripts/deploy.sh` (SSH par clé) — jamais
`ssh` interactif avec des commandes ad hoc.

## Rollback d'un déploiement

Depuis la Phase 3, le rollback est **automatique** : si le health-check post-déploiement échoue
(`.github/workflows/deploy.yml`, jobs `staging`/`prod`), la CI restaure elle-même le commit
précédent (`git reset --hard` vers le SHA capturé juste avant le `git pull`) et relance `pm2`. Le
job CI reste rouge malgré le rollback réussi — c'est volontaire, pour forcer une investigation
avant le prochain déploiement plutôt que de laisser croire que tout va bien.

**Rollback manuel** (si l'automatique a lui-même échoué, ou en dehors de la CI) :
```bash
ssh -i <clé> deploy@hrflow.novatech.io
cd /var/www/hrflow
git log --oneline -5          # identifier le dernier commit sain
git reset --hard <sha>
npm install --production
pm2 restart all
curl -sf https://hrflow.novatech.io/health
```

## Restauration d'une sauvegarde

Sauvegardes horaires via `scripts/backup-db.sh` (cron sur l'hôte de prod, voir en-tête du
script). Pour restaurer :
```bash
DATABASE_URL=postgresql://... ./scripts/restore-db.sh latest
# ou un fichier précis :
DATABASE_URL=postgresql://... ./scripts/restore-db.sh /var/backups/hrflow/hrflow-20260723T140000Z.sql.gz
```
`backup-db.sh` et `restore-db.sh` ont été testés de bout en bout (backup → suppression d'une
table → restauration → données bien récupérées) avec un Postgres jetable — voir
`docs/RAPPORT-ETAT-CORRECTIONS.md`, section Phase 3, pour le détail du test.

**Vérifier qu'une sauvegarde existe et n'est pas vide avant de compter dessus en cas d'incident :**
```bash
ls -lh /var/backups/hrflow/ | tail -5
```

## Monitoring / alerte

`.github/workflows/uptime-check.yml` ping `/health` toutes les 5 minutes et poste sur un webhook
(`ALERT_WEBHOOK_URL`, à créer dans les secrets du repo) si ça échoue. C'est un filet minimal, pas
un remplacement d'un vrai outil d'observabilité (pas de métriques, pas de traces, pas d'astreinte
formelle) — voir `docs/RAPPORT-ETAT-CORRECTIONS.md` pour ce qui reste hors de portée.

## En cas d'incident (alerte uptime, remontée client, etc.)

Checklist directement issue de ce qui a manqué en août 2024 :

1. **Confirmer** : `curl -sf https://hrflow.novatech.io/health`. Si ça répond, le problème est
   ailleurs (une route précise, pas le service entier) — vérifier les logs `pm2 logs` sur le
   serveur avant de supposer une panne totale.
2. **Ne pas improviser de migration ou de correctif en prod.** Si une régression vient d'un
   déploiement récent, préférer le rollback (section ci-dessus) à un correctif à chaud.
3. **Vérifier l'état de la base** avant de restaurer un backup — une restauration écrase les
   données plus récentes que le backup choisi. Ne restaurer que si les données sont réellement
   corrompues/perdues, pas par réflexe.
4. **Documenter pendant l'incident**, pas après : heure de début, ce qui a été tenté, l'heure de
   résolution. Un post-mortem écrit à froid plusieurs jours après (comme
   `docs/incident-aout-2024.md`) perd les détails utiles.
5. **Après résolution** : vérifier que les actions décidées dans le post-mortem sont
   effectivement suivies d'effet — celles d'août 2024 ne l'avaient jamais été avant cet audit.

## Secrets à configurer côté GitHub (Settings → Secrets and variables → Actions)

| Secret | Contenu |
|---|---|
| `PROD_HOST` / `STAGING_HOST` | Adresse des serveurs |
| `PROD_SSH_KEY` / `STAGING_SSH_KEY` | Clé privée SSH (remplace les anciens `*_SSH_PASSWORD`) |
| `ALERT_WEBHOOK_URL` | URL de webhook entrant (Slack/Teams/Discord) pour les alertes uptime |

La clé publique correspondante doit être ajoutée à `~deploy/.ssh/authorized_keys` sur chaque
serveur, et son host key doit être dans le `known_hosts` de l'agent qui exécute `scripts/deploy.sh`
en dehors de la CI (le script utilise `StrictHostKeyChecking=yes`, volontairement — pas de bypass
silencieux d'une alerte de clé d'hôte inconnue/changée).
