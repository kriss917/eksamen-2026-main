locals {
  metric_namespace = local.name
  ecs_cluster      = "default"
}

resource "aws_cloudwatch_dashboard" "wishifai" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Business: analyserte bilder og gaveforslag"
          view   = "timeSeries"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            [local.metric_namespace, "wishifai.images.analyzed.count"],
            [local.metric_namespace, "wishifai.gifts.suggested.count"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Tid per kall: Bedrock vs Rekognition (gjennomsnitt)"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            [local.metric_namespace, "wishifai.bedrock.duration.avg"],
            [local.metric_namespace, "wishifai.rekognition.duration.avg"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Bedrock: svar som ikke kunne tolkes"
          view   = "timeSeries"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            [local.metric_namespace, "wishifai.bedrock.parse.failures.count"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS: CPU og minne (%)"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_express_gateway_service.wishifai.service_name, "ClusterName", local.ecs_cluster],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_express_gateway_service.wishifai.service_name, "ClusterName", local.ecs_cluster],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ECS: kjørende tasks"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "LiveTaskCount", "ServiceName", aws_ecs_express_gateway_service.wishifai.service_name, "ClusterName", local.ecs_cluster],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Actuator: HTTP-latens for POST /api/analyze"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            [local.metric_namespace, "http.server.requests.avg", "exception", "none", "method", "POST", "error", "none", "uri", "/api/analyze", "outcome", "SUCCESS", "status", "200"],
            [local.metric_namespace, "http.server.requests.max", "exception", "none", "method", "POST", "error", "none", "uri", "/api/analyze", "outcome", "SUCCESS", "status", "200"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Actuator: JVM heap-minne brukt"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            [local.metric_namespace, "jvm.memory.used.value", "area", "heap", "id", "G1 Old Gen"],
            [local.metric_namespace, "jvm.memory.used.value", "area", "heap", "id", "G1 Eden Space"],
          ]
        }
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "bedrock_parse_failures" {
  alarm_name          = "${local.name}-bedrock-parse-failures"
  alarm_description   = "Bedrock-svar som ikke var gyldig JSON og ble erstattet med (ukjent)"
  namespace           = local.metric_namespace
  metric_name         = "wishifai.bedrock.parse.failures.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "bedrock_slow" {
  alarm_name          = "${local.name}-bedrock-slow"
  alarm_description   = "Gjennomsnittlig Bedrock-kall tar over 20 sekunder"
  namespace           = local.metric_namespace
  metric_name         = "wishifai.bedrock.duration.avg"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}