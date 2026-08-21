# Config alerte Email — seuils & simulation

Date : 2026-08-20

## Contexte

Demande : mettre en place des alertes par Email, avec des seuils
définis et une simulation permettant de valider que la chaîne d'alerte
fonctionne bout en bout.

Décision : pas de PagerDuty pour l'instant (période d'essai limitée à 14
jours et nécessite d'être admin du Teams PagerDuty). On reste sur
**Email uniquement**, via le mécanisme SNS déjà en place dans
`terraform/modules/monitoring/main.tf` (topic SNS + abonnement email +
alarmes CloudWatch). Cela ne bloque pas la demande : le mail par défaut
envoyé par CloudWatch via SNS est déjà détaillé (nom d'alarme, raison du
déclenchement, métrique, seuil franchi, horodatage), et on peut le rendre
encore plus explicite via le champ `alarm_description` de chaque alarme.

## État actuel

Implémenté dans `terraform/modules/monitoring/main.tf` (par couleur,
blue+green) et `terraform/main.tf` (ressources partagées ALB/RDS) — voir
[Noms des alarmes](#noms-des-alarmes) ci-dessous. Reste à faire un
`terraform apply` pour créer réellement ces alarmes côté AWS.

## Seuils standards proposés

Basé sur l'architecture du projet (2×EC2 t3 k3s blue/green, RDS
`db.t4g.micro` 20GB partagée, ALB avec 2 target groups) :

| Ressource | Métrique | Seuil proposé | Évaluation | Sévérité | Pourquoi |
|---|---|---|---|---|---|
| EC2 (blue+green) | `StatusCheckFailed` | > 0 | 3 × 60s | Critique | *déjà en place* — instance injoignable |
| EC2 (blue+green) | `CPUUtilization` | > 80% | 5 × 60s (Average) | Warning | saturation avant impact utilisateur |
| ALB | `UnHealthyHostCount` (par target group) | ≥ 1 | 2 × 60s | Critique | pods/app down alors que l'EC2 répond — distingue panne infra vs panne appli |
| ALB | `HTTPCode_Target_5XX_Count` | ≥ 5 | 5 × 60s (Sum) | Critique | erreurs applicatives (compte absolu plutôt que taux, plus fiable en faible trafic) |
| ALB | `TargetResponseTime` | > 2s | 5 × 60s (Average) | Warning | dégradation de latence |
| RDS | `CPUUtilization` | > 80% | 5 × 60s | Warning | saturation DB |
| RDS | `FreeStorageSpace` | < 2 GB (10% de 20GB) | 2 × 300s | Critique | disque plein = DB HS |
| RDS | `FreeableMemory` | < 150 MB | 3 × 60s | Warning | `t4g.micro` a peu de marge (1GB RAM total) |

Un seul seuil par métrique (pas de palier warning + critique séparé) :
sans PagerDuty pour gérer l'escalade, multiplier les paliers ajoute surtout
du bruit dans une boîte mail. Les valeurs sont à ajuster si le trafic réel
observé diffère fortement de ces hypothèses (ex. seuil 5xx à 5 potentiellement
trop sensible en très faible trafic).

## Rendre l'email explicite

Le champ `alarm_description` de chaque `aws_cloudwatch_metric_alarm` apparaît
tel quel dans le corps de l'email AWS. Actuellement seule l'alarme
`ec2-down` en a une. Écrire une description explicite pour chaque nouvelle
alarme, par exemple :

> *"RDS `hrflow-production-postgres` : espace disque < 10%. Risque d'arrêt
> de la base si non traité. Vérifier `terraform output rds_endpoint` puis
> la console RDS → Storage."*

Combiné à un `alarm_name` parlant (`${project_name}-ec2-down`, et de même
pour `alb-5xx`, `rds-storage-low`, etc.), l'objet du mail
(`ALARM: "hrflow-production-rds-storage-low" in EU (Paris)`) + la
description suffisent à comprendre le problème sans avoir à chercher
ailleurs — pas besoin de Lambda ou d'outil tiers pour ça.

Exemple complet du mail reçu (objet + corps) : voir
[`exemple-email-alerte.md`](./exemple-email-alerte.md).

## Noms des alarmes

`project_name` vaut `my-project` en staging et `hrflow-production` en
production (`terraform/staging.tfvars` / `production.tfvars`) :

| Alarme | Staging | Production |
|---|---|---|
| EC2 down (blue) | `my-project-ec2-down` | `hrflow-production-ec2-down` |
| EC2 down (green) | `my-project-green-ec2-down` | `hrflow-production-green-ec2-down` |
| EC2 CPU haut (blue) | `my-project-ec2-cpu-high` | `hrflow-production-ec2-cpu-high` |
| EC2 CPU haut (green) | `my-project-green-ec2-cpu-high` | `hrflow-production-green-ec2-cpu-high` |
| ALB unhealthy (blue) | `my-project-alb-unhealthy-blue` | `hrflow-production-alb-unhealthy-blue` |
| ALB unhealthy (green) | `my-project-alb-unhealthy-green` | `hrflow-production-alb-unhealthy-green` |
| ALB 5xx | `my-project-alb-5xx-high` | `hrflow-production-alb-5xx-high` |
| ALB latence | `my-project-alb-latency-high` | `hrflow-production-alb-latency-high` |
| RDS CPU | `my-project-rds-cpu-high` | `hrflow-production-rds-cpu-high` |
| RDS storage | `my-project-rds-storage-low` | `hrflow-production-rds-storage-low` |
| RDS mémoire | `my-project-rds-memory-low` | `hrflow-production-rds-memory-low` |

## Simulation

Pré-requis : les alarmes doivent être appliquées (`terraform apply`), et
AWS CLI configuré (droits `cloudwatch:SetAlarmState`, région `eu-west-3`).

Pour prouver que la chaîne fonctionne bout en bout sans attendre un vrai
incident, `aws cloudwatch set-alarm-state` force artificiellement l'état
d'une alarme — ça déclenche les mêmes `alarm_actions` (donc le même email)
que si le seuil avait réellement été franchi :

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "<nom-alarme>" \
  --state-value ALARM \
  --state-reason "Simulation manuelle" \
  --region eu-west-3
```

Exemple concret (staging, EC2 CPU) :

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "my-project-ec2-cpu-high" \
  --state-value ALARM \
  --state-reason "Simulation manuelle" \
  --region eu-west-3
```

### Commandes prêtes à l'emploi (toutes les alarmes, staging)

À adapter avec les noms `hrflow-production-*` pour tester en production.

```bash
# EC2 down (blue)
aws cloudwatch set-alarm-state --region eu-west-3 --alarm-name "my-project-ec2-down" --state-value ALARM --state-reason "Simulation : EC2 blue injoignable"

# EC2 down (green)
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-green-ec2-down" \
  --state-value ALARM --state-reason "Simulation : EC2 green injoignable"

# EC2 CPU haut (blue)
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-ec2-cpu-high" \
  --state-value ALARM --state-reason "Simulation : CPU EC2 blue > 80%"

# EC2 CPU haut (green)
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-green-ec2-cpu-high" \
  --state-value ALARM --state-reason "Simulation : CPU EC2 green > 80%"

# ALB unhealthy (blue)
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-alb-unhealthy-blue" \
  --state-value ALARM --state-reason "Simulation : cible blue en échec de health check"

# ALB unhealthy (green)
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-alb-unhealthy-green" \
  --state-value ALARM --state-reason "Simulation : cible green en échec de health check"

# ALB 5xx
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-alb-5xx-high" \
  --state-value ALARM --state-reason "Simulation : pic d'erreurs 5xx sur l'ALB"

# ALB latence
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-alb-latency-high" \
  --state-value ALARM --state-reason "Simulation : temps de réponse ALB > 2s"

# RDS CPU
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-rds-cpu-high" \
  --state-value ALARM --state-reason "Simulation : CPU RDS > 80%"

# RDS storage
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-rds-storage-low" \
  --state-value ALARM --state-reason "Simulation : espace disque RDS < 2 Go"

# RDS mémoire
aws cloudwatch set-alarm-state --region eu-west-3 \
  --alarm-name "my-project-rds-memory-low" \
  --state-value ALARM --state-reason "Simulation : mémoire libre RDS < 150 Mo"
```

Pour repasser toutes les alarmes de staging à `OK` après test :

```bash
for alarm in my-project-ec2-down my-project-green-ec2-down \
  my-project-ec2-cpu-high my-project-green-ec2-cpu-high \
  my-project-alb-unhealthy-blue my-project-alb-unhealthy-green \
  my-project-alb-5xx-high my-project-alb-latency-high \
  my-project-rds-cpu-high my-project-rds-storage-low my-project-rds-memory-low; do
  aws cloudwatch set-alarm-state --region eu-west-3 \
    --alarm-name "$alarm" --state-value OK --state-reason "Fin de simulation"
done
```

Vérifier la réception de l'email, puis repasser l'alarme à `OK` pour
vérifier la notification de résolution :

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "<nom-alarme>" \
  --state-value OK \
  --state-reason "Fin de simulation" \
  --region eu-west-3
```

exemple : 
```bash
aws cloudwatch set-alarm-state --alarm-name "my-project-ec2-down" --state-value OK --state-reason "Fin de simulation" --region eu-west-3
```

Sans attendre l'email, on peut aussi vérifier l'état directement :

```bash
aws cloudwatch describe-alarms --alarm-names "<nom-alarme>" \
  --query "MetricAlarms[0].StateValue" --region eu-west-3
```

exemple:
```bash
aws cloudwatch describe-alarms --alarm-names "my-project-ec2-down" --query "MetricAlarms[0].StateValue" --region eu-west-3
```

Pour valider le déclenchement réel du seuil (pas seulement la
notification), une alternative plus lourde existe pour le CPU
(`stress-ng --cpu 2 --timeout 300s` sur l'instance via SSM), mais
`set-alarm-state` reste recommandé pour toutes les alarmes : il valide la
chaîne complète (CloudWatch → SNS → email) sans risque ni attente, y
compris pour storage/mémoire RDS où simuler la vraie condition serait
impraticable.

## Prochaines étapes

- Valider/ajuster les valeurs de seuils ci-dessus si besoin.
- `terraform apply` (staging d'abord) pour créer les alarmes.
- Exécuter la simulation `set-alarm-state` sur chaque alarme pour valider
  la réception email.
