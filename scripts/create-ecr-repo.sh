#!/bin/bash
# ============================================================
#  Create ECR Repository
# ============================================================
#  Run this on the EC2 instance after configuring AWS CLI.
#
#  Usage:
#    chmod +x create-ecr-repo.sh
#    ./create-ecr-repo.sh
# ============================================================

AWS_REGION="ap-south-1"        # Change to your region
ECR_REPO_NAME="devops-demo"

echo "📦 Creating ECR repository: ${ECR_REPO_NAME}"

aws ecr create-repository \
    --repository-name ${ECR_REPO_NAME} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE

echo ""
echo "✅ ECR Repository created!"
echo ""
echo "Repository URI:"
aws ecr describe-repositories \
    --repository-names ${ECR_REPO_NAME} \
    --region ${AWS_REGION} \
    --query 'repositories[0].repositoryUri' \
    --output text
