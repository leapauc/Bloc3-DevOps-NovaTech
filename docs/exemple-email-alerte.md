# Exemple d'email d'alerte

Date : 2026-08-20

Ce document montre le contenu exact d'un email d'alerte tel qu'il sera reçu
sur `alert_email`, pour l'alarme `hrflow-production-rds-storage-low`
implémentée dans `terraform/main.tf`. Le format (objet + corps) est celui
généré nativement par CloudWatch lors de la notification SNS → email ; seul
le champ **Description** est du contenu qu'on contrôle (`alarm_description`
dans le code Terraform).

Il ne s'agit pas d'une capture d'écran réelle (les alarmes ne sont pas
encore appliquées en prod) mais d'un exemple fidèle au format standard AWS,
pour valider que la description répond bien à l'exigence "le mail précise
le souci" avant simulation réelle.

## Comment obtenir le vrai email (simulation)

```bash
aws cloudwatch set-alarm-state \
  --alarm-name hrflow-production-rds-storage-low \
  --state-value ALARM \
  --state-reason "Test de simulation"

# puis, pour vérifier la notification de résolution :
aws cloudwatch set-alarm-state \
  --alarm-name hrflow-production-rds-storage-low \
  --state-value OK \
  --state-reason "Fin du test de simulation"
```

---

## Email reçu

**De :** AWS Notifications <no-reply@sns.amazonaws.com>
**À :** lea.pauchot@gmail.com
**Objet :** ALARM: "hrflow-production-rds-storage-low" in EU (Paris)

```
You are receiving this email because your Amazon CloudWatch Alarm
"hrflow-production-rds-storage-low" in the EU (Paris) region has entered
the ALARM state, because "Threshold Crossed: 2 out of the last 2
datapoints [1.72 (20/08/26 09:47:00), 1.65 (20/08/26 09:42:00)] were less
than the threshold (2147483648.0) (minimum 2 datapoints for OK -> ALARM
transition)." at "Thursday 20 August, 2026 09:47:12 UTC".

Alarm Details:
- Name:                       hrflow-production-rds-storage-low
- Description:                La base RDS (hrflow-production-postgres) a
                               moins de 2 Go d'espace disque libre (< 10%
                               des 20 Go alloués). Risque d'arrêt de la
                               base si non traité. Vérifier la console
                               RDS → Storage et envisager une augmentation
                               de allocated_storage.
- State Change:                OK -> ALARM
- Reason for State Change:     Threshold Crossed: 2 out of the last 2
                               datapoints [1.72 (20/08/26 09:47:00), 1.65
                               (20/08/26 09:42:00)] were less than the
                               threshold (2147483648.0) (minimum 2
                               datapoints for OK -> ALARM transition).
- Timestamp:                   Thursday 20 August, 2026 09:47:12 UTC
- AWS Account:                 079716036671
- Alarm Arn:                   arn:aws:cloudwatch:eu-west-3:079716036671:
                               alarm:hrflow-production-rds-storage-low

Threshold:
- The alarm is in the ALARM state when the metric is LessThanThreshold
  2147483648.0 for at least 2 out of the last 2 datapoint(s), which is a
  sequence of 2 datapoints each 300 seconds long.

Monitored Metric:
- MetricNamespace:            AWS/RDS
- MetricName:                 FreeStorageSpace
- Dimensions:                 [DBInstanceIdentifier =
                               hrflow-production-postgres]
- Period:                     300 seconds
- Statistic:                  Average
- Unit:                       Bytes

State Change Actions:
- OK:                [arn:aws:sns:eu-west-3:079716036671:hrflow-production-alerts]
- ALARM:              [arn:aws:sns:eu-west-3:079716036671:hrflow-production-alerts]
- INSUFFICIENT_DATA:

View this alarm in the AWS Management Console:
https://eu-west-3.console.aws.amazon.com/cloudwatch/home?region=eu-west-3#alarmsV2:alarm/hrflow-production-rds-storage-low
```

---

## Ce que ce format apporte déjà

- **Objet** : nomme l'alarme et la région — identifiable en un coup d'œil dans la boîte mail.
- **Description** : le champ qu'on contrôle, rédigé pour répondre à 3 questions : *quoi* (espace disque < 2 Go), *pourquoi c'est grave* (risque d'arrêt de la base), *quoi faire* (console RDS → Storage, augmenter `allocated_storage`).
- **Reason for State Change** : la valeur réelle mesurée vs. le seuil, avec horodatage des points de mesure — permet de juger la gravité sans se connecter à la console.
- **Monitored Metric** : namespace/métrique/dimension exacts, utile pour retrouver l'alarme dans CloudWatch.

Le même modèle de description explicite est appliqué à toutes les alarmes ajoutées dans `terraform/main.tf` et `terraform/modules/monitoring/main.tf` (CPU EC2, CPU/mémoire RDS, unhealthy hosts ALB, 5xx ALB, latence ALB).
