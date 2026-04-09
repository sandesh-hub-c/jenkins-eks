#!/bin/bash
# ============================================================
#  Cleanup Script — Tear Down All AWS Resources
# ============================================================
#  Run this when you're done with the demo to avoid charges.
#
#  Usage:
#    chmod +x cleanup.sh
#    ./cleanup.sh
# ============================================================

AWS_REGION="ap-south-1"
CLUSTER_NAME="devops-demo-cluster"
ECR_REPO_NAME="devops-demo"

echo "⚠️  This will DELETE all resources created for the demo!"
echo "   - EKS Cluster: ${CLUSTER_NAME}"
echo "   - ECR Repository: ${ECR_REPO_NAME}"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cancelled."
    exit 0
fi

echo ""
echo "1️⃣  Deleting Kubernetes services (to release LoadBalancer)..."
kubectl delete svc devops-demo-service 2>/dev/null || true
sleep 10

echo "2️⃣  Deleting EKS Cluster..."
eksctl delete cluster --name ${CLUSTER_NAME} --region ${AWS_REGION}

echo "3️⃣  Deleting ECR Repository..."
aws ecr delete-repository \
    --repository-name ${ECR_REPO_NAME} \
    --region ${AWS_REGION} \
    --force

echo ""
echo "✅ All resources deleted!"
echo ""
echo "📌 Don't forget to:"
echo "   - Terminate the EC2 instance"
echo "   - Delete the IAM role if no longer needed"
echo "   - Check for any remaining EBS volumes or Elastic IPs"
