# 📘 Instructor Guide: Jenkins CI/CD to AWS EKS

## Complete Step-by-Step Walkthrough

This guide walks you through setting up and running the entire CI/CD pipeline demo — from launching an EC2 instance to seeing your app live on EKS.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Launch EC2 Instance](#3-step-1-launch-ec2-instance)
4. [Step 2: IAM Setup](#4-step-2-iam-setup)
5. [Step 3: Run Install Script](#5-step-3-run-install-script)
6. [Step 4: Configure AWS CLI](#6-step-4-configure-aws-cli)
7. [Step 5: Create ECR Repository](#7-step-5-create-ecr-repository)
8. [Step 6: Create EKS Cluster](#8-step-6-create-eks-cluster)
9. [Step 7: Setup Jenkins](#9-step-7-setup-jenkins)
10. [Step 8: Configure Jenkins Credentials](#10-step-8-configure-jenkins-credentials)
11. [Step 9: Create Jenkins Pipeline](#11-step-9-create-jenkins-pipeline)
12. [Step 10: Run the Pipeline](#12-step-10-run-the-pipeline)
13. [Step 11: Verify Deployment](#13-step-11-verify-deployment)
14. [Troubleshooting](#14-troubleshooting)
15. [Cleanup](#15-cleanup)
16. [Teaching Notes](#16-teaching-notes)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    DEVELOPER                             │
│                  (pushes code)                           │
└──────────────┬──────────────────────────────────────────┘
               │ git push
               ▼
┌─────────────────────────────────────────────────────────┐
│                  GitHub Repository                       │
│          (Spring Boot + Dockerfile + Jenkinsfile)         │
└──────────────┬──────────────────────────────────────────┘
               │ webhook / poll
               ▼
┌─────────────────────────────────────────────────────────┐
│              EC2 Instance (Jenkins Server)                │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────────┐  │
│  │ Jenkins │ │  Maven  │ │ Docker  │ │ kubectl/aws  │  │
│  └────┬────┘ └────┬────┘ └────┬────┘ └──────┬───────┘  │
│       │           │           │              │           │
│       └───────────┴───────────┴──────────────┘           │
│                      Pipeline                            │
└──────────────┬──────────────────┬───────────────────────┘
               │ push image       │ kubectl apply
               ▼                  ▼
┌──────────────────┐  ┌───────────────────────────────────┐
│   Amazon ECR     │  │         Amazon EKS                 │
│  (Image Registry)│  │  ┌──────┐ ┌──────┐ ┌──────────┐  │
│                  │  │  │ Pod1 │ │ Pod2 │ │   ELB    │  │
│  devops-demo:1   │──▶  │      │ │      │ │(public)  │  │
│  devops-demo:2   │  │  └──────┘ └──────┘ └──────────┘  │
│  devops-demo:latest│ │                                   │
└──────────────────┘  └───────────────────────────────────┘
```

### What Happens in Each Stage:

| Stage | What Happens | Tool Used |
|-------|-------------|-----------|
| **Checkout** | Jenkins pulls code from Git | Git |
| **Build** | Maven compiles Java code, creates JAR | Maven |
| **Test** | Maven runs unit tests | Maven + JUnit |
| **Docker Build** | Docker creates container image | Docker |
| **Push to ECR** | Image is pushed to AWS registry | Docker + AWS CLI |
| **Deploy to EKS** | Kubernetes manifests are applied | kubectl |
| **Verify** | Pod and service status is checked | kubectl |

---

## 2. Prerequisites

Before starting the demo, ensure you have:

- [x] An **AWS Account** with admin access
- [x] An **SSH key pair** created in AWS (to connect to EC2)
- [x] A **GitHub account** (to host the source code)
- [x] A **terminal** with SSH client (macOS Terminal, Windows PuTTY, etc.)

### AWS Free Tier Note

> ⚠️ **This demo will incur AWS charges.** EKS is NOT free tier eligible.
> - EKS Control Plane: ~$0.10/hr (~$2.40/day)
> - EC2 t2.medium: ~$0.0464/hr  
> - Worker Nodes (2x t3.medium): ~$0.0832/hr
> - **Estimated total: ~$5-8 for a full-day demo**
> - **Always run cleanup when done!**

---

## 3. Step 1: Launch EC2 Instance

### 3.1 Go to AWS Console → EC2 → Launch Instance

### 3.2 Configure the instance:

| Setting | Value |
|---------|-------|
| **Name** | `Jenkins-DevOps-Server` |
| **AMI** | Amazon Linux 2023 (or Amazon Linux 2) |
| **Instance Type** | `t2.medium` (minimum — 2 vCPU, 4 GB RAM) |
| **Key Pair** | Select your existing key pair (or create new) |
| **Storage** | 30 GB gp3 (default 8 GB is too small) |

### 3.3 Configure Security Group

Create a new security group with these inbound rules:

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | Your IP | SSH access |
| Custom TCP | 8080 | 0.0.0.0/0 | Jenkins Web UI |
| HTTP | 80 | 0.0.0.0/0 | Testing (optional) |

### 3.4 Launch and Connect

```bash
# Connect to your EC2 instance
ssh -i "your-key.pem" ec2-user@<EC2-PUBLIC-IP>
```

> 💡 **Teaching Point:** Explain to students why we use t2.medium — Jenkins + Maven builds need at least 4 GB RAM. Smaller instances will run out of memory during Maven builds.

---

## 4. Step 2: IAM Setup

You need an IAM role attached to the EC2 instance and IAM credentials for Jenkins.

### 4.1 Create IAM Role for EC2

1. Go to **IAM → Roles → Create Role**
2. Select **AWS Service → EC2**
3. Attach these policies:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonEKSServicePolicy`
   - `AmazonEC2FullAccess`
   - `AmazonVPCFullAccess`
   - `IAMFullAccess`
   - `CloudFormationFullAccess`
4. Name it: `Jenkins-EKS-Role`
5. Go to **EC2 → Select Instance → Actions → Security → Modify IAM Role**
6. Attach `Jenkins-EKS-Role`

### 4.2 Create IAM User for Jenkins Credentials

1. Go to **IAM → Users → Create User**
2. Name: `jenkins-eks-user`
3. Attach same policies as above (or use `AdministratorAccess` for demo)
4. Go to **Security Credentials → Create Access Key**
5. Select "Application running outside AWS"
6. **Save the Access Key ID and Secret Access Key** — you'll need them for Jenkins

### Required IAM Policies Summary

```
AmazonEKSClusterPolicy           → Manage EKS clusters
AmazonEKSWorkerNodePolicy        → Manage EKS worker nodes
AmazonEC2ContainerRegistryFullAccess → Push/pull Docker images to ECR
AmazonEKSServicePolicy           → EKS service operations
AmazonEC2FullAccess              → EC2 operations (for eksctl)
AmazonVPCFullAccess              → VPC setup (for eksctl)
IAMFullAccess                    → Create service-linked roles
CloudFormationFullAccess         → eksctl uses CloudFormation
```

> 💡 **Teaching Point:** In production, you'd follow the principle of least privilege. For this demo, we use broader permissions for simplicity. Discuss what minimal permissions would look like.

---

## 5. Step 3: Run Install Script

### 5.1 Upload the project to GitHub

First, push this entire project to a GitHub repository:

```bash
# On your local machine (where the project files are)
cd Jenkins-eks
git init
git add .
git commit -m "Initial commit - DevOps demo project"
git branch -M main
git remote add origin https://github.com/<YOUR-USERNAME>/Jenkins-eks.git
git push -u origin main
```

### 5.2 Clone and run install script on EC2

```bash
# On the EC2 instance
git clone https://github.com/<YOUR-USERNAME>/Jenkins-eks.git
cd Jenkins-eks

# Make scripts executable
chmod +x scripts/*.sh

# Run the install script
sudo ./scripts/install.sh
```

### 5.3 Verify installations

```bash
java -version          # Should show Java 17
mvn -version           # Should show Maven 3.x
docker --version       # Should show Docker
aws --version          # Should show AWS CLI v2
kubectl version --client   # Should show kubectl
eksctl version         # Should show eksctl
```

### 5.4 Check Jenkins is running

```bash
sudo systemctl status jenkins
```

> 💡 **Teaching Point:** Walk through the install script and explain what each section does. This is a great opportunity to discuss infrastructure as code and repeatable environments.

---

## 6. Step 4: Configure AWS CLI

```bash
# Configure AWS CLI with your credentials
aws configure
```

Enter:
- **AWS Access Key ID:** (from IAM user you created)
- **AWS Secret Access Key:** (from IAM user you created)  
- **Default region:** `ap-south-1` (or your preferred region)
- **Output format:** `json`

### Verify:

```bash
aws sts get-caller-identity
```

Should show your account ID and user ARN.

---

## 7. Step 5: Create ECR Repository

```bash
# Run the ECR creation script
./scripts/create-ecr-repo.sh
```

Or manually:

```bash
aws ecr create-repository \
    --repository-name devops-demo \
    --region ap-south-1 \
    --image-scanning-configuration scanOnPush=true
```

### Note your ECR URI:

```
<AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/devops-demo
```

> 💡 **Teaching Point:** Explain what ECR is — Amazon's private Docker registry. Compare it to Docker Hub. Discuss why companies use private registries.

---

## 8. Step 6: Create EKS Cluster

> ⏰ **This step takes 15-20 minutes.** Start it and use the waiting time to explain Kubernetes concepts.

```bash
# Run the EKS creation script
./scripts/create-eks-cluster.sh
```

Or manually:

```bash
eksctl create cluster \
    --name devops-demo-cluster \
    --region ap-south-1 \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed
```

### Verify cluster:

```bash
kubectl get nodes
```

Should show 2 nodes in `Ready` status.

### While Waiting — Concepts to Explain:

1. **What is Kubernetes?** — Container orchestration platform
2. **What is EKS?** — AWS managed Kubernetes (AWS handles the control plane)
3. **Nodes vs Pods** — Nodes are VMs, Pods are the smallest deployable units
4. **What eksctl does** — Creates VPC, subnets, node groups, and the cluster itself via CloudFormation

---

## 9. Step 7: Setup Jenkins

### 9.1 Access Jenkins UI

Open in browser: `http://<EC2-PUBLIC-IP>:8080`

### 9.2 Unlock Jenkins

Get the initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Paste it into the Jenkins UI.

### 9.3 Install Plugins

Select **"Install suggested plugins"** and wait for installation.

Then install these **additional plugins** (Manage Jenkins → Plugins → Available):

| Plugin | Purpose |
|--------|---------|
| **Pipeline: AWS Steps** | AWS credential integration in pipelines |
| **Amazon ECR** | ECR authentication |
| **Docker Pipeline** | Docker commands in Jenkins pipeline |
| **AWS Credentials** | Store AWS access keys securely |
| **Kubernetes CLI** | kubectl in pipelines |

### 9.4 Create Admin User

Create your Jenkins admin user when prompted.

> 💡 **Teaching Point:** Explain Jenkins plugins as extensions. Jenkins is modular by design — you install only what you need.

---

## 10. Step 8: Configure Jenkins Credentials

### 10.1 Add AWS Credentials

1. Go to **Manage Jenkins → Credentials → System → Global credentials**
2. Click **"Add Credentials"**
3. Configure:

| Field | Value |
|-------|-------|
| **Kind** | AWS Credentials |
| **ID** | `aws-credentials` |
| **Description** | AWS Access Keys for ECR/EKS |
| **Access Key ID** | (your IAM user access key) |
| **Secret Access Key** | (your IAM user secret key) |

4. Click **Save**

> ⚠️ **The credential ID must be exactly `aws-credentials`** — this is what the Jenkinsfile references.

### 10.2 Add Git Credentials (if repo is private)

1. **Add Credentials** → Kind: **Username with password**
2. Username: your GitHub username
3. Password: your GitHub personal access token
4. ID: `git-credentials`

---

## 11. Step 9: Create Jenkins Pipeline

### 11.1 Update Jenkinsfile

Before creating the pipeline, update the Jenkinsfile environment variables.

On the EC2 instance, edit the Jenkinsfile:

```bash
cd ~/Jenkins-eks

# Get your AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: $AWS_ACCOUNT_ID"

# Update the Jenkinsfile
sed -i "s/YOUR_AWS_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" Jenkinsfile

# If your region is different, also update:
# sed -i "s/ap-south-1/us-east-1/g" Jenkinsfile
```

Commit and push:

```bash
git add Jenkinsfile
git commit -m "Update AWS Account ID in Jenkinsfile"
git push origin main
```

### 11.2 Create Pipeline in Jenkins

1. Go to Jenkins Dashboard → **New Item**
2. Enter name: `devops-demo-pipeline`
3. Select **"Pipeline"** → Click OK
4. Configure:

**General:**
- Description: "CI/CD Pipeline for DevOps Demo App"

**Pipeline:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/<YOUR-USERNAME>/Jenkins-eks.git`
- Credentials: (select git-credentials if private repo)
- Branch: `*/main`
- Script Path: `Jenkinsfile`

5. Click **Save**

> 💡 **Teaching Point:** Explain "Pipeline as Code" — the Jenkinsfile lives in the same repository as the application code. This means CI/CD configuration is version-controlled, reviewable, and traceable.

---

## 12. Step 10: Run the Pipeline

### 12.1 Ensure Jenkins User Has Cluster Access

Before running the pipeline, the jenkins user needs kubectl access to the EKS cluster:

```bash
# On EC2, copy kubeconfig for jenkins user
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
```

### 12.2 Ensure Jenkins User Can Use Docker

```bash
# Verify jenkins is in docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Wait a moment, then verify
sleep 15
sudo -u jenkins docker ps
```

### 12.3 Trigger the Build

1. Go to `devops-demo-pipeline` in Jenkins
2. Click **"Build Now"**
3. Click on the build number → **"Console Output"** to watch live

### Expected Pipeline Output:

```
[Pipeline] stage (Checkout)
📥 Pulling source code from Git...

[Pipeline] stage (Build with Maven)
🔨 Building application with Maven...
BUILD SUCCESS

[Pipeline] stage (Run Tests)
🧪 Running unit tests...
Tests run: 1, Failures: 0

[Pipeline] stage (Build Docker Image)
🐳 Building Docker image...
Successfully built abc123

[Pipeline] stage (Push to ECR)
📤 Pushing Docker image to Amazon ECR...
Login Succeeded
pushed: latest

[Pipeline] stage (Deploy to EKS)
🚀 Deploying to Amazon EKS...
deployment.apps/devops-demo configured
service/devops-demo-service configured
deployment "devops-demo" successfully rolled out

[Pipeline] stage (Verify)
✅ Verifying deployment...
NAME          READY   STATUS    RESTARTS
devops-demo   2/2     Running   0

🎉 Pipeline completed successfully!
```

> 💡 **Teaching Point:** Walk through each stage and explain what's happening. Show how the console output maps to the Jenkinsfile stages.

---

## 13. Step 11: Verify Deployment

### 13.1 Check Pods

```bash
kubectl get pods -l app=devops-demo
```

Expected output:
```
NAME                          READY   STATUS    RESTARTS   AGE
devops-demo-7d8f9b6c4-abc12   1/1     Running   0          2m
devops-demo-7d8f9b6c4-def34   1/1     Running   0          2m
```

### 13.2 Get the LoadBalancer URL

```bash
kubectl get svc devops-demo-service
```

Expected output:
```
NAME                  TYPE           CLUSTER-IP     EXTERNAL-IP                                           PORT(S)
devops-demo-service   LoadBalancer   10.100.x.x     a1b2c3-1234.ap-south-1.elb.amazonaws.com             80:31234/TCP
```

> ⏰ The EXTERNAL-IP may show `<pending>` for 1-2 minutes while AWS provisions the ELB.

### 13.3 Test the Application

```bash
# Get the LoadBalancer URL
LB_URL=$(kubectl get svc devops-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test endpoints
curl http://$LB_URL/
curl http://$LB_URL/health
curl http://$LB_URL/info
```

Expected responses:

```json
// GET /
{
    "message": "Welcome to the DevOps Demo App!",
    "status": "UP",
    "timestamp": "2026-04-10 00:30:00"
}

// GET /health
{
    "status": "healthy",
    "timestamp": "2026-04-10 00:30:00"
}

// GET /info
{
    "application": "devops-demo",
    "version": "1.0.0",
    "timestamp": "2026-04-10 00:30:00",
    "hostname": "devops-demo-7d8f9b6c4-abc12"
}
```

> 💡 **Teaching Point:** Call `/info` multiple times and show how the hostname changes — this demonstrates Kubernetes load balancing across pods!

### 13.4 Show Rolling Update (Bonus Demo)

1. Make a small change to `HelloController.java` (e.g., change the version to "2.0.0")
2. Commit and push to GitHub
3. Click "Build Now" in Jenkins again
4. Watch the rolling update happen:

```bash
kubectl get pods -w -l app=devops-demo
```

Students will see new pods come up and old pods terminate — zero downtime deployment!

---

## 14. Troubleshooting

### ❌ Jenkins can't run Docker

```bash
# Error: permission denied while trying to connect to Docker daemon
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### ❌ Maven build fails with OutOfMemory

```bash
# EC2 instance is too small. Ensure t2.medium or larger.
# Or add swap:
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswp /swapfile
sudo swapon /swapfile
```

### ❌ kubectl: No connection to EKS

```bash
# Ensure kubeconfig is updated
aws eks update-kubeconfig --name devops-demo-cluster --region ap-south-1

# For jenkins user:
sudo -u jenkins aws eks update-kubeconfig --name devops-demo-cluster --region ap-south-1
```

### ❌ ECR login fails

```bash
# Ensure AWS credentials are configured
aws sts get-caller-identity

# Manual ECR login test:
aws ecr get-login-password --region ap-south-1 | \
    docker login --username AWS --password-stdin \
    <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com
```

### ❌ EKS cluster creation fails

```bash
# Check CloudFormation for errors:
aws cloudformation list-stacks --region ap-south-1

# Ensure IAM roles have sufficient permissions
# Ensure you haven't hit VPC/EIP limits in the region
```

### ❌ LoadBalancer stuck on "pending"

```bash
# Check events for the service:
kubectl describe svc devops-demo-service

# Common cause: security group limits or missing subnet tags
# eksctl usually handles this, but verify:
kubectl get events --sort-by='.lastTimestamp'
```

### ❌ Pods in CrashLoopBackOff

```bash
# Check pod logs:
kubectl logs -l app=devops-demo

# Check pod details:
kubectl describe pod -l app=devops-demo
```

---

## 15. Cleanup

> ⚠️ **IMPORTANT:** Always clean up after the demo to avoid ongoing charges!

### Run the cleanup script:

```bash
./scripts/cleanup.sh
```

### Or manually:

```bash
# 1. Delete Kubernetes services first (to release the ELB)
kubectl delete svc devops-demo-service

# 2. Wait 1-2 minutes for ELB to be released

# 3. Delete EKS cluster (takes ~10 minutes)
eksctl delete cluster --name devops-demo-cluster --region ap-south-1

# 4. Delete ECR repository
aws ecr delete-repository \
    --repository-name devops-demo \
    --region ap-south-1 \
    --force

# 5. Terminate the EC2 instance from AWS Console

# 6. Delete IAM role and user from AWS Console
```

### Checklist after cleanup:

- [ ] EKS cluster deleted
- [ ] ECR repository deleted
- [ ] EC2 instance terminated
- [ ] No lingering EBS volumes
- [ ] No lingering Elastic IPs
- [ ] IAM role/user deleted (if no longer needed)

---

## 16. Teaching Notes

### Recommended Session Flow (3-4 hours)

| Time | Activity | Duration |
|------|----------|----------|
| 0:00 | Intro: What is CI/CD? DevOps overview | 20 min |
| 0:20 | Step 1-2: Launch EC2, IAM setup | 20 min |
| 0:40 | Step 3: Run install script, explain tools | 15 min |
| 0:55 | Step 4-5: AWS CLI config, create ECR | 10 min |
| 1:05 | Step 6: Create EKS (start it, explain K8s while waiting) | 25 min |
| 1:30 | **Break** | 10 min |
| 1:40 | Step 7-8: Jenkins setup, credentials | 20 min |
| 2:00 | Step 9: Walkthrough the Jenkinsfile | 15 min |
| 2:15 | Step 10: Run pipeline, explain each stage | 20 min |
| 2:35 | Step 11: Verify, test endpoints, rolling update demo | 20 min |
| 2:55 | Q&A + Discussion | 15 min |
| 3:10 | Cleanup | 10 min |

### Key Concepts to Emphasize

1. **CI/CD Pipeline** — Automated workflow from code commit to production deployment
2. **Infrastructure as Code** — Install script, Jenkinsfile, K8s manifests are all code
3. **Containerization** — Docker packages the app with all its dependencies
4. **Container Orchestration** — Kubernetes manages multiple containers, handles scaling and failover
5. **Rolling Updates** — Zero-downtime deployments by gradually replacing old pods
6. **Health Probes** — Kubernetes checks if pods are healthy before routing traffic
7. **Image Registry** — ECR stores versioned Docker images securely
8. **Declarative Pipeline** — Jenkins pipeline defined as code (Jenkinsfile)

### Discussion Questions for Students

1. What would happen if one of the pods crashes? (K8s restarts it automatically)
2. How would you scale to handle more traffic? (Increase replicas or add HPA)
3. Why do we use a multi-stage Dockerfile? (Smaller image, faster deployments)
4. What's the difference between liveness and readiness probes?
5. Why push to a private registry (ECR) instead of Docker Hub?
6. How would you add a database to this setup? (RDS + K8s secrets)
7. What happens during a rolling update if the new version is broken? (Readiness probe fails, rollback)

### Suggested Follow-Up Topics

- **Helm Charts** — Templatized Kubernetes deployments
- **Horizontal Pod Autoscaler** — Auto-scaling based on CPU/memory
- **Ingress Controllers** — More advanced routing than LoadBalancer
- **Secrets Management** — AWS Secrets Manager + K8s secrets
- **Monitoring** — Prometheus + Grafana on EKS
- **GitOps** — ArgoCD for declarative deployments
