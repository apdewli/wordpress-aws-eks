terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

module "transit_gateway" {
  source = "./modules/transit-gateway"
  
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

module "eks" {
  source = "./modules/eks"
  
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  
  depends_on = [module.vpc]
}

module "rds" {
  source = "./modules/rds"
  
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  db_subnets   = module.vpc.db_subnets
}

module "elasticache" {
  source = "./modules/elasticache"
  
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
}

module "s3_cloudfront" {
  source = "./modules/s3-cloudfront"
  
  project_name = var.project_name
}

module "alb" {
  source = "./modules/alb"
  
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  
  depends_on = [module.eks]
}

module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
}

module "codebuild" {
  source = "./modules/codebuild"
  
  project_name = var.project_name
  ecr_repo_url = module.ecr.repository_url
  eks_cluster_name = module.eks.cluster_name
}

module "codepipeline" {
  source = "./modules/codepipeline"
  
  project_name = var.project_name
  codebuild_project = module.codebuild.project_name
  source_bucket = var.source_bucket_name
}

module "wordpress" {
  source = "./modules/wordpress"
  
  project_name     = var.project_name
  rds_endpoint     = module.rds.endpoint
  redis_endpoint   = module.elasticache.endpoint
  s3_bucket        = module.s3_cloudfront.bucket_name
  cloudfront_url   = module.s3_cloudfront.cloudfront_url
  ecr_repo_url     = module.ecr.repository_url
  
  depends_on = [module.eks, module.alb, module.ecr]
}