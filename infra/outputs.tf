output "bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "service_arn" {
  value = aws_ecs_express_gateway_service.wishifai.service_arn
}

output "ingress_paths" {
  value = aws_ecs_express_gateway_service.wishifai.ingress_paths
}

output "service_url" {
  value = aws_ecs_express_gateway_service.wishifai.ingress_paths[0].endpoint
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.wishifai.dashboard_name
}