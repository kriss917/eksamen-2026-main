variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "candidate_number" {
  type    = string
  default = "10"
}

variable "image_tag" {
  type        = string
  description = "Tag på imaget i ECR (commit-SHA)"
}

variable "ecr_repository" {
  type    = string
  default = "wishifai-10"
}

variable "execution_role_arn" {
  type    = string
  default = "arn:aws:iam::244530008913:role/ecsTaskExecutionRole"
}

variable "infrastructure_role_arn" {
  type    = string
  default = "arn:aws:iam::244530008913:role/service-role/ecsInfrastructureRoleForExpressServices"
}