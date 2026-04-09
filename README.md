# DevOps Demo: Spring Boot → Jenkins → EKS

A complete CI/CD demo project that deploys a Spring Boot REST API to AWS EKS using Jenkins.

## 📁 Project Structure

```
Jenkins-eks/
├── src/
│   ├── main/
│   │   ├── java/com/devops/demo/
│   │   │   ├── DemoApplication.java          # Spring Boot entry point
│   │   │   └── controller/
│   │   │       └── HelloController.java      # REST API endpoints
│   │   └── resources/
│   │       └── application.properties        # App configuration
│   └── test/
│       └── java/com/devops/demo/
│           └── DemoApplicationTests.java     # Unit tests
├── k8s/
│   ├── deployment.yaml                       # Kubernetes Deployment
│   └── service.yaml                          # Kubernetes Service (LoadBalancer)
├── scripts/
│   ├── install.sh                            # EC2 setup script (all tools)
│   ├── create-ecr-repo.sh                    # Create ECR repository
│   ├── create-eks-cluster.sh                 # Create EKS cluster
│   └── cleanup.sh                            # Tear down all resources
├── Dockerfile                                # Multi-stage Docker build
├── Jenkinsfile                               # Declarative CI/CD pipeline
├── pom.xml                                   # Maven build configuration
└── README.md                                 # This file
```

## 🚀 Quick Start

See **[INSTRUCTOR-GUIDE.md](INSTRUCTOR-GUIDE.md)** for the complete step-by-step walkthrough.

## 🔗 API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Welcome message with status |
| `GET /health` | Health check (used by K8s probes) |
| `GET /info` | App info with hostname (pod name) |

## ⚙️ Tech Stack

| Tool | Purpose |
|------|---------|
| **Spring Boot 3.2** | Java REST API framework |
| **Maven** | Build & dependency management |
| **Docker** | Containerization |
| **Jenkins** | CI/CD automation |
| **AWS ECR** | Docker image registry |
| **AWS EKS** | Managed Kubernetes |
| **kubectl** | Kubernetes CLI |
| **eksctl** | EKS cluster management |

## 💰 Cost Warning

> ⚠️ Running this demo will incur AWS charges. Use the `scripts/cleanup.sh` script when done.
> - EKS cluster: ~$0.10/hour
> - EC2 (t2.medium): ~$0.0464/hour  
> - Worker nodes (2x t3.medium): ~$0.0832/hour
