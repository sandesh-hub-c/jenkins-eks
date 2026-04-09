#!/bin/bash
# ============================================================
#  Create EKS Cluster using eksctl
# ============================================================
#  Run this on the EC2 instance after configuring AWS CLI.
#  ⚠️  This takes 15-20 minutes to complete.
#
#  Usage:
#    chmod +x create-eks-cluster.sh
#    ./create-eks-cluster.sh
# ============================================================

AWS_REGION="ap-south-1"                   # Change to your region
CLUSTER_NAME="devops-demo-cluster"
NODE_TYPE="t3.medium"                     # Instance type for worker nodes
NODE_COUNT=2                              # Number of worker nodes

echo "🚀 Creating EKS Cluster: ${CLUSTER_NAME}"
echo "   Region:     ${AWS_REGION}"
echo "   Node Type:  ${NODE_TYPE}"
echo "   Node Count: ${NODE_COUNT}"
echo ""
echo "⏳ This will take 15-20 minutes..."
echo ""

eksctl create cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --node-type ${NODE_TYPE} \
    --nodes ${NODE_COUNT} \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed

echo ""
echo "✅ EKS Cluster created!"
echo ""

# Verify the cluster
echo "📋 Cluster info:"
kubectl cluster-info
echo ""
echo "📋 Nodes:"
kubectl get nodes
