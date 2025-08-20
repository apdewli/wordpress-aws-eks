#!/bin/bash

# AWS Infrastructure Deployment Script
echo "Starting AWS Infrastructure Deployment..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

if [ $? -ne 0 ]; then
    echo "Terraform initialization failed!"
    exit 1
fi

# Plan the deployment
echo "Planning Terraform deployment..."
terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    echo "Terraform planning failed!"
    exit 1
fi

# Apply the deployment
echo "Applying Terraform deployment..."
terraform apply tfplan

if [ $? -eq 0 ]; then
    echo "Deployment completed successfully!"
    
    # Configure kubectl
    echo "Configuring kubectl..."
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
    aws eks update-kubeconfig --region us-west-2 --name $CLUSTER_NAME
    
    echo "Infrastructure is ready!"
else
    echo "Deployment failed!"
    exit 1
fi