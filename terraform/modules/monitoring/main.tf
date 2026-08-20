# modules/monitoring/main.tf

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name = "${var.project_name}-ec2-down"

  alarm_description = "L'EC2 K3s (${var.project_name}) ne répond plus aux status checks AWS depuis 3 minutes. Si c'est la couleur active, le trafic public est impacté. Vérifier l'état de l'instance dans la console EC2 (system log, statut) ; en cas de doute, basculer sur l'autre couleur via le workflow rollback.yml."

  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed"

  dimensions = {
    InstanceId = var.instance_id
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  treat_missing_data = "breaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  ok_actions = [
    aws_sns_topic.alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name = "${var.project_name}-ec2-cpu-high"

  alarm_description = "L'EC2 K3s (${var.project_name}) a un CPU moyen > 80% depuis 5 minutes. Risque de latence ou d'instabilité des pods. Vérifier la charge (kubectl top pods/nodes) et investiguer une éventuelle fuite de ressources ou un pic de trafic."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    InstanceId = var.instance_id
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 5

  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  # Pas de donnée = instance probablement éteinte/idle (pas de trafic) plutôt
  # qu'un souci de charge : contrairement à ec2_status_check, on ne veut pas
  # déclencher une alerte "CPU haut" sur une absence de métrique.
  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  ok_actions = [
    aws_sns_topic.alerts.arn
  ]
}