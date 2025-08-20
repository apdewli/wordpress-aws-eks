variable "project_name" {
  description = "Project name"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis endpoint"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "cloudfront_url" {
  description = "CloudFront URL"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}