// ============================================================
// Jenkins Declarative Pipeline
// CI/CD: Build → Docker → ECR → Deploy to EKS
// ============================================================
//
// PREREQUISITES (configure in Jenkins):
//   1. AWS credentials stored as Jenkins credentials (ID: 'aws-credentials')
//   2. Git credentials if repo is private (ID: 'git-credentials')
//   3. Environment variables set below (AWS_ACCOUNT_ID, AWS_REGION, etc.)
// ============================================================

pipeline {
    agent any

    environment {
        // ─── CHANGE THESE TO MATCH YOUR AWS SETUP ───
        AWS_ACCOUNT_ID  = 'YOUR_AWS_ACCOUNT_ID'       // e.g., 123456789012
        AWS_REGION      = 'ap-south-1'                 // e.g., us-east-1, ap-south-1
        ECR_REPO_NAME   = 'devops-demo'                // ECR repository name
        EKS_CLUSTER     = 'devops-demo-cluster'        // EKS cluster name
        // ─── AUTO-COMPUTED (do not change) ───
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        FULL_IMAGE      = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    }

    stages {

        // ────────────────────────────────────────────
        // Stage 1: Checkout source code from Git
        // ────────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo '📥 Pulling source code from Git...'
                checkout scm
            }
        }

        // ────────────────────────────────────────────
        // Stage 2: Build JAR using Maven
        // ────────────────────────────────────────────
        stage('Build with Maven') {
            steps {
                echo '🔨 Building application with Maven...'
                sh 'mvn clean package -DskipTests -B'
            }
        }

        // ────────────────────────────────────────────
        // Stage 3: Run unit tests
        // ────────────────────────────────────────────
        stage('Run Tests') {
            steps {
                echo '🧪 Running unit tests...'
                sh 'mvn test -B'
            }
        }

        // ────────────────────────────────────────────
        // Stage 4: Build Docker image
        // ────────────────────────────────────────────
        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image: ${FULL_IMAGE}"
                sh "docker build -t ${FULL_IMAGE} ."
                sh "docker tag ${FULL_IMAGE} ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
            }
        }

        // ────────────────────────────────────────────
        // Stage 5: Login to ECR and push Docker image
        // ────────────────────────────────────────────
        stage('Push to ECR') {
            steps {
                echo '📤 Pushing Docker image to Amazon ECR...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker push ${FULL_IMAGE}
                        docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest
                    """
                }
            }
        }

        // ────────────────────────────────────────────
        // Stage 6: Deploy to EKS using kubectl
        // ────────────────────────────────────────────
        stage('Deploy to EKS') {
            steps {
                echo '🚀 Deploying to Amazon EKS...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        # Update kubeconfig for the EKS cluster
                        aws eks update-kubeconfig \
                            --name ${EKS_CLUSTER} \
                            --region ${AWS_REGION}

                        # Replace placeholder image in deployment manifest
                        sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' k8s/deployment.yaml

                        # Apply Kubernetes manifests
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml

                        # Wait for rollout to complete
                        kubectl rollout status deployment/devops-demo \
                            --timeout=120s
                    """
                }
            }
        }

        // ────────────────────────────────────────────
        // Stage 7: Verify Deployment
        // ────────────────────────────────────────────
        stage('Verify') {
            steps {
                echo '✅ Verifying deployment...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        echo "─── Pods ───"
                        kubectl get pods -l app=devops-demo
                        echo ""
                        echo "─── Service ───"
                        kubectl get svc devops-demo-service
                        echo ""
                        echo "─── Deployment ───"
                        kubectl get deployment devops-demo
                    """
                }
            }
        }
    }

    post {
        success {
            echo '🎉 Pipeline completed successfully! Application deployed to EKS.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs above for details.'
        }
        always {
            // Clean up Docker images on the Jenkins server to save disk space
            sh "docker rmi ${FULL_IMAGE} || true"
            sh "docker rmi ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest || true"
        }
    }
}
