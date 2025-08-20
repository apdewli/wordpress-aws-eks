output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "cloudfront_url" {
  value = module.s3_cloudfront.cloudfront_url
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "source_bucket" {
  value = module.codepipeline.source_bucket
}

output "pipeline_name" {
  value = module.codepipeline.pipeline_name
}