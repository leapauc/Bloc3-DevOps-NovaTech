# Runbook Incident — de la détection (P1) au rollback

Date : 2026-08-20

Ce document couvre l'infrastructure **actuelle** (Blue-Green EC2/k3s + ALB +
RDS partagée, `terraform/`, workflows `.github/workflows/deploy.yml` et
`rollback.yml`). Il complète `docs/alerting-seuils-simulation.md` (seuils
des alarmes) et `docs/exemple-email-alerte.md` (format des notifications).

> ℹ️ `docs/RUNBOOK.md` est un document antérieur, écrit pour une archi
> mono-serveur SSH/pm2 qui n'existe plus (migration vers Blue-Green depuis).
> En cas d'incident, se fier à **ce** document.

## 1. Classification de sévérité

| Sévérité | Définition | Exemples (alarmes définies dans `terraform/main.tf` / `modules/monitoring`) |
|---|---|---|
| **P1 — Critique** | Trafic public impacté, ou risque imminent de coupure totale | `*-ec2-down` sur la couleur **active** ; `*-alb-unhealthy-<couleur active>` ; `*-alb-5xx-high` ; `*-rds-storage-low` (RDS partagée blue+green — impacte tout le monde) |
| **P2 — Majeur** | Dégradation de service, pas de coupure | `*-ec2-cpu-high` / `*-rds-cpu-high` ; `*-alb-latency-high` ; `*-rds-memory-low` |
| **P3 — Mineur** | Pas d'impact utilisateur | Toute alarme sur la couleur **idle** (elle ne sert pas de trafic — cf. `terraform/main.tf`, commentaire du job `deploy-idle`) |

**Point clé Blue-Green** : la couleur (blue/green) concernée par l'alarme
change tout. Vérifier `active_color` avant de qualifier la sévérité :
```bash
cd terraform
terraform workspace select production   # ou staging
terraform output -raw active_color
```
Une alarme `*-ec2-down` sur la couleur **idle** n'est pas un P1 — c'est
l'instance qui reçoit le prochain déploiement, pas celle qui sert le trafic.

## 2. Détection

- **Email d'alerte** (SNS → `alert_email`) : objet `ALARM: "<nom-alarme>" in EU (Paris)`. Le corps précise la métrique, le seuil franchi et l'action à mener (`alarm_description`) — voir `docs/exemple-email-alerte.md`.
- **Remontée manuelle** (client, test manuel) : traiter comme un P1 tant que non qualifié différemment (cf. §1).

## 3. Étape 1 — Confirmer l'incident

Ne jamais rollback sur la seule foi d'un email : vérifier l'impact réel.

```bash
# Le site répond-il ?
curl -fsS -o /dev/null -w "%{http_code}\n" http://<alb_dns_name>/

# Quelle couleur est active, et laquelle est visée par l'alarme ?
cd terraform && terraform workspace select production
terraform output -raw active_color

# État actuel de l'alarme qui a notifié
aws cloudwatch describe-alarms --alarm-names "<nom-alarme>" \
  --query "MetricAlarms[0].[StateValue,StateReason]" --region eu-west-3
```

URLs ALB (stables, ne changent jamais — cf. README) :

| Environnement | URL |
|---|---|
| Staging | http://my-project-alb-843501151.eu-west-3.elb.amazonaws.com |
| Production | http://hrflow-production-alb-568207110.eu-west-3.elb.amazonaws.com |

Si l'alarme concerne un service applicatif précis (pods), se connecter via
SSM sur l'instance de la couleur concernée (cf. `deploy.yml`, job
`deploy-idle`, étapes SSM) :
```bash
aws ssm start-session --target <instance_id>
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -n hrflow-<environment>
kubectl logs -n hrflow-<environment> -l app=<service> --tail=100
```

## 4. Étape 2 — Décider : rollback ou investigation ?

```
L'alarme touche-t-elle la couleur ACTIVE (trafic public réellement impacté) ?
├─ NON (couleur idle) → Pas de rollback nécessaire. Corriger avant le
│                        prochain déploiement (l'idle sert de zone de test).
└─ OUI
   ├─ Cause = régression d'un déploiement récent (ALB 5xx, unhealthy,
   │  ec2-down juste après un push sur main) → ROLLBACK (§5), immédiat.
   ├─ Cause = RDS (storage/CPU/mémoire) → ⚠️ Le rollback ALB NE RÈGLE RIEN :
   │  la RDS est PARTAGÉE entre blue et green (cf. terraform/main.tf,
   │  commentaire "discipline additive-only"). Basculer de couleur ne
   │  change pas la base qui sert les deux. Traiter directement la RDS
   │  (libérer de l'espace, tuer une requête bloquante `pg_stat_activity`,
   │  augmenter `allocated_storage` en dernier recours).
   └─ Cause = pic de charge légitime (pas une régression) → scaler plutôt
      que rollback (`REPLICAS` dans deploy.yml, ou `rds_instance_class`).
```

## 5. Étape 3 — Déclencher le rollback (cas régression applicative)

Le rollback Blue-Green ne redéploie rien : il rebascule le listener ALB
vers l'autre couleur, qui tourne déjà la dernière version connue-bonne
(c'est le principe même du Blue-Green — cf. `rollback.yml`). Bascule en
quelques secondes, pas de downtime.

**Via l'interface GitHub** :
1. Onglet **Actions** du repo → workflow **HRFlow Rollback**.
2. **Run workflow** → choisir `environment` (`staging` ou `production`).
3. Lancer, suivre les logs (job `rollback`).

**Via GitHub CLI** :
```bash
gh workflow run rollback.yml -f environment=production
```

Le workflow détermine seul la couleur cible (`terraform output active_color`
puis bascule vers l'autre), applique le changement de listener ALB, et
vérifie via `curl` que l'ALB sert bien la nouvelle couleur avant de terminer.

## 6. Étape 4 — Vérifier le rollback

```bash
curl -fsS http://<alb_dns_name>/ > /dev/null && echo OK
curl -fsS http://<alb_dns_name>/api-docs/json > /dev/null && echo "Gateway + 4 services OK"

cd terraform && terraform workspace select production
terraform output -raw active_color   # doit refléter la couleur rollback
```

Repasser l'alarme d'origine à `OK` une fois l'impact confirmé résolu
(CloudWatch le fera automatiquement à la prochaine évaluation si la
métrique est effectivement revenue sous le seuil — inutile de forcer
`set-alarm-state` en situation réelle, ça sert uniquement à la simulation).

## 7. Étape 5 — Communication (pendant l'incident, pas après)

Documenter en temps réel (pas a posteriori — c'est exactement ce qui a
manqué lors de l'incident du 14/15 août 2024, cf.
`docs/old/incident-aout-2024.md`) :
- Heure de détection, heure de confirmation, heure de rollback, heure de
  résolution.
- Ce qui a été tenté et pourquoi (ex. "rollback écarté car cause = RDS
  partagée").
- Qui a été notifié / doit l'être (client si impact visible côté produit).

## 8. Étape 6 — Post-mortem

Après résolution, rédiger un post-mortem court (même gabarit que
`docs/old/incident-aout-2024.md`) :
- Résumé + durée + impact.
- Chronologie.
- Cause racine (pas juste le symptôme — ex. "5xx" n'est pas une cause,
  "déploiement d'une migration non rétro-compatible" en est une).
- Actions décidées, avec un propriétaire et une échéance — et un suivi
  réel derrière (le post-mortem d'août 2024 listait des actions jamais
  faites, cf. section "Status" de ce document).

## Annexes

### Alarmes existantes

Voir `docs/alerting-seuils-simulation.md#noms-des-alarmes` pour la liste
complète (staging/production) et les seuils.

### Rollback vs re-déploiement — ne pas confondre

- **Rollback** (`rollback.yml`) : bascule de trafic instantanée, aucune
  reconstruction. À utiliser en premier réflexe pour une régression
  applicative détectée juste après un déploiement.
- **Nouveau déploiement** (`pipeline.yml` → `deploy.yml`) : nécessaire si
  la cause n'est pas liée au dernier déploiement (ex. fuite mémoire lente,
  incident RDS) ou si un correctif de code est requis avant de pouvoir
  revenir en service normalement.
