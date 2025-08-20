# WordPress AWS EKS Infrastructure

This Terraform project automates the setup of a comprehensive AWS infrastructure for a WordPress application with CI/CD pipeline integration.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Developer     │───▶│  S3 Source   │───▶│  CodePipeline   │
│   Commits       │    │   Bucket     │    │                 │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                                     │
                                                     ▼
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   CloudFront    │    │     ECR      │◀───│   CodeBuild     │
│   (Static)      │    │  Repository  │    │   (Build/Deploy)│
└─────────────────┘    └──────────────┘    └─────────────────┘
         │                       │                   │
         ▼                       ▼                   ▼
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   S3 Bucket     │    │     EKS      │    │   Helm Chart    │
│  (Static Files) │    │   Cluster    │    │  (WordPress)    │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  RDS MySQL +    │
                       │ ElastiCache     │
                       └─────────────────┘
```

## Architecture Components

### Networking Infrastructure
- **VPC** with 3 Availability Zones (configurable CIDR)
- **Public Subnets** (configurable CIDR blocks)
- **Private Subnets** (configurable CIDR blocks)
- **Database Subnets** (configurable CIDR blocks)
- **NAT Gateways** in each AZ for outbound internet access
- **Transit Gateway** for Direct Connect integration
- **Internet Gateway** for public subnet access

### Compute & Container Platform
- **EKS Cluster** (v1.28) with OIDC provider and RBAC
- **EKS Node Groups** with auto-scaling (t3.medium instances)
- **Application Load Balancer** for ingress controller
- **Security Groups** with least privilege access

### Database & Caching
- **RDS MySQL** (8.0) in private subnets with encryption
- **ElastiCache Redis** (7.0) for session storage with encryption
- **Automated backups** and maintenance windows

### Content Delivery & Storage
- **S3 Bucket** for static content with public access blocked
- **CloudFront** distribution with OAC for secure S3 access
- **ECR Repository** for Docker images with lifecycle policies

### CI/CD Pipeline
- **S3 Source Bucket** for code repository
- **CodePipeline** for automated deployment workflow
- **CodeBuild** for building Docker images and Helm deployments
- **IAM Roles** with specific permissions for each service

### Application Deployment
- **WordPress** deployed via Bitnami Helm chart
- **Custom Docker image** with Redis session support
- **Kubernetes Ingress** with ALB integration
- **Horizontal Pod Autoscaling** support

## Prerequisites

### Required Tools
1. **AWS CLI** v2.x configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **kubectl** >= 1.21 for Kubernetes management
4. **Helm** >= 3.0 for package management
5. **Docker** for local testing (optional)

### AWS Permissions Required
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*", "eks:*", "rds:*", "elasticache:*",
        "s3:*", "cloudfront:*", "ecr:*",
        "codebuild:*", "codepipeline:*",
        "iam:*", "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Step-by-Step Deployment Guide

### 1. Initial Setup

```bash
# Clone or download the project
cd wordpress-aws-eks

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
```

### 2. Prepare Source Code for CI/CD Pipeline

**IMPORTANT**: Before deploying the infrastructure, you must first create an S3 bucket and upload your source code:

```bash
# Create S3 bucket for source code (use a unique name)
aws s3 mb s3://your-unique-wordpress-source-bucket

# Create deployment package
zip -r source.zip Dockerfile wp-config.php buildspec.yml

# Upload source code to S3 bucket
aws s3 cp source.zip s3://your-unique-wordpress-source-bucket/source.zip
```

**Note**: Replace `your-unique-wordpress-source-bucket` with your actual bucket name.

### 3. Configure Variables

Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
project_name = "my-wordpress-app"
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
source_bucket_name = "your-unique-wordpress-source-bucket"  # Use the S3 bucket you created above

# Customize subnet CIDR blocks as needed
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
db_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
```

### 4. Deploy Infrastructure

#### Option A: Using the deployment script
```bash
chmod +x deploy.sh
./deploy.sh
```

#### Option B: Manual Terraform commands
```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Apply the infrastructure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name $(terraform output -raw eks_cluster_name)
```

### 5. Verify Infrastructure Deployment

```bash
# Check Terraform outputs
terraform output

# Verify EKS cluster
kubectl cluster-info

# Check nodes
kubectl get nodes

# Verify namespaces
kubectl get namespaces
```

## Post-Deployment Configuration

### 1. Install AWS Load Balancer Controller

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 2. Trigger CI/CD Pipeline

Since you already uploaded the source code during setup, the pipeline should automatically trigger. Monitor the deployment:

```bash
# Monitor pipeline status
aws codepipeline get-pipeline-state --name $(terraform output -raw pipeline_name)

# If you need to trigger manually or upload new code:
SOURCE_BUCKET=$(terraform output -raw source_bucket)
zip -r source.zip Dockerfile wp-config.php buildspec.yml
aws s3 cp source.zip s3://$SOURCE_BUCKET/source.zip
```

### 3. Monitor Deployment

```bash
# Watch CodeBuild logs
aws logs tail /aws/codebuild/$(terraform output -raw eks_cluster_name)-build --follow

# Check WordPress deployment
kubectl get pods -n wordpress
kubectl get services -n wordpress
kubectl get ingress -n wordpress

# Get application URL
kubectl get ingress -n wordpress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

## Application Access and Management

### Accessing WordPress

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "WordPress URL: http://$ALB_DNS"

# Or get from ingress
kubectl get ingress -n wordpress
```

### Kubernetes Management Commands

```bash
# View all resources in wordpress namespace
kubectl get all -n wordpress

# Check pod logs
kubectl logs -n wordpress deployment/wordpress

# Scale WordPress deployment
kubectl scale deployment wordpress -n wordpress --replicas=3

# Port forward for local access (if needed)
kubectl port-forward -n wordpress service/wordpress 8080:80

# Execute commands in WordPress pod
kubectl exec -it -n wordpress deployment/wordpress -- /bin/bash
```

### Database Access

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
echo "RDS Endpoint: $RDS_ENDPOINT"

# Connect via bastion host (if configured)
# mysql -h $RDS_ENDPOINT -u admin -p wordpress
```

### Monitoring and Troubleshooting

```bash
# Check cluster health
kubectl get componentstatuses

# View events
kubectl get events -n wordpress --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n wordpress

# Describe problematic resources
kubectl describe pod <pod-name> -n wordpress
kubectl describe ingress -n wordpress
```

## CI/CD Pipeline Management

### Pipeline Operations

```bash
# Start pipeline manually
aws codepipeline start-pipeline-execution --name $(terraform output -raw pipeline_name)

# Get pipeline status
aws codepipeline get-pipeline-state --name $(terraform output -raw pipeline_name)

# View build logs
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/
```

### ECR Management

```bash
# List images in ECR
aws ecr list-images --repository-name $(terraform output -raw ecr_repository_url | cut -d'/' -f2)

# Login to ECR (for manual pushes)
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)
```

## Maintenance and Updates

### Updating WordPress

```bash
# Update Helm chart
helm repo update
helm upgrade wordpress bitnami/wordpress -n wordpress

# Or trigger via pipeline by updating source code
```

### Scaling Operations

```bash
# Scale EKS nodes
aws eks update-nodegroup-config --cluster-name $CLUSTER_NAME --nodegroup-name <nodegroup-name> --scaling-config minSize=2,maxSize=6,desiredSize=4

# Scale WordPress pods
kubectl scale deployment wordpress -n wordpress --replicas=5
```

## Security Considerations

- **Network Security**: RDS and ElastiCache in private subnets
- **Encryption**: All data encrypted at rest and in transit
- **Access Control**: IAM roles with least privilege principles
- **Container Security**: ECR image scanning enabled
- **Secrets Management**: Kubernetes secrets for sensitive data
- **Network Policies**: Consider implementing Kubernetes network policies

## Backup and Disaster Recovery

```bash
# RDS automated backups are enabled (7-day retention)
# Manual snapshot
aws rds create-db-snapshot --db-instance-identifier <db-instance-id> --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d)

# Backup WordPress files
kubectl exec -n wordpress deployment/wordpress -- tar czf /tmp/wp-backup.tar.gz /var/www/html
kubectl cp wordpress/<pod-name>:/tmp/wp-backup.tar.gz ./wp-backup.tar.gz
```

## Cleanup

### Complete Infrastructure Removal

```bash
# Delete Helm releases first
helm uninstall wordpress -n wordpress
helm uninstall aws-load-balancer-controller -n kube-system

# Destroy Terraform infrastructure
terraform destroy

# Clean up any remaining resources manually if needed
```

## Troubleshooting Common Issues

### EKS Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name $CLUSTER_NAME

# Check IAM permissions
aws sts get-caller-identity
```

### WordPress Not Accessible
```bash
# Check ingress
kubectl describe ingress -n wordpress

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Pipeline Failures
```bash
# Check CodeBuild logs
aws logs tail /aws/codebuild/<project-name> --follow

# Verify IAM permissions for CodeBuild role
```

## Cost Optimization

- Use **Spot Instances** for EKS node groups in non-production
- Implement **Horizontal Pod Autoscaling** for WordPress
- Configure **Cluster Autoscaler** for EKS nodes
- Set up **CloudWatch** alarms for cost monitoring
- Use **Reserved Instances** for RDS in production

## Support and Documentation

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [WordPress on Kubernetes Best Practices](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

## Network Customization

### Subnet CIDR Configuration

The infrastructure uses dynamic subnet CIDR blocks that can be customized in `terraform.tfvars`:

```hcl
# Main VPC CIDR block
vpc_cidr = "10.0.0.0/16"

# Public subnet CIDRs (one per AZ)
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

# Private subnet CIDRs (one per AZ)
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

# Database subnet CIDRs (one per AZ)
db_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
```

### Alternative Network Configurations

**Example 1: Different IP Range**
```hcl
vpc_cidr = "172.16.0.0/16"
public_subnet_cidrs = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
private_subnet_cidrs = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
db_subnet_cidrs = ["172.16.20.0/24", "172.16.21.0/24", "172.16.22.0/24"]
```

**Example 2: Larger Subnets**
```hcl
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
private_subnet_cidrs = ["10.0.16.0/22", "10.0.20.0/22", "10.0.24.0/22"]
db_subnet_cidrs = ["10.0.32.0/24", "10.0.33.0/24", "10.0.34.0/24"]
```