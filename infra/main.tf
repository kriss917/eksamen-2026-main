data "aws_caller_identity" "current" {}

locals {
  name  = "wishifai-${var.candidate_number}"
  image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository}:${var.image_tag}"
}

resource "aws_s3_bucket" "images" {
  bucket        = "${local.name}-images"
  force_destroy = true
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "wishifai-task-role-${var.candidate_number}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.images.arn, "${aws_s3_bucket.images.arn}/*"]
  }
  statement {
    actions   = ["rekognition:DetectLabels"]
    resources = ["*"]
  }
  statement {
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"]
  }
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "wishifai-task-policy-${var.candidate_number}"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_permissions.json
}

resource "aws_ecs_express_gateway_service" "wishifai" {
  service_name            = local.name
  execution_role_arn      = var.execution_role_arn
  infrastructure_role_arn = var.infrastructure_role_arn
  task_role_arn           = aws_iam_role.task.arn
  health_check_path       = "/actuator/health"

  primary_container {
    image          = local.image
    container_port = 8080

    environment {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.images.bucket
    }
    environment {
      name  = "AWS_REGION"
      value = var.region
    }
  }
}