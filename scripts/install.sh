#!/bin/bash
# ============================================================
#  EC2 DevOps Setup Script — install.sh
# ============================================================
#  Installs ALL tools needed on a single EC2 instance:
#    ✅ Java 17 (Amazon Corretto)
#    ✅ Jenkins
#    ✅ Maven
#    ✅ Docker
#    ✅ AWS CLI v2
#    ✅ kubectl
#    ✅ eksctl
#
#  Usage:
#    chmod +x install.sh
#    sudo ./install.sh
#
#  Tested on: Amazon Linux 2023 / Amazon Linux 2
# ============================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}  ℹ️  $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root: sudo ./install.sh${NC}"
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# 1. SYSTEM UPDATE
# ──────────────────────────────────────────────────────────────
print_header "1/7 — Updating System Packages"
yum update -y
print_success "System updated"

# ──────────────────────────────────────────────────────────────
# 2. JAVA 17 (Amazon Corretto)
# ──────────────────────────────────────────────────────────────
print_header "2/7 — Installing Java 17 (Amazon Corretto)"
yum install -y java-17-amazon-corretto-devel

# Set JAVA_HOME
JAVA_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=${JAVA_PATH}" >> /etc/profile.d/devops.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/devops.sh

java -version
print_success "Java 17 installed"

# ──────────────────────────────────────────────────────────────
# 3. JENKINS
# ──────────────────────────────────────────────────────────────
print_header "3/7 — Installing Jenkins"

# Add Jenkins repository
wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
yum install -y jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
sleep 10

print_success "Jenkins installed and running on port 8080"
print_info "Initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "  (Jenkins may still be starting...)"

# ──────────────────────────────────────────────────────────────
# 4. MAVEN
# ──────────────────────────────────────────────────────────────
print_header "4/7 — Installing Maven"

yum install -y maven 2>/dev/null || {
    # If maven is not in default repos, install manually
    MAVEN_VERSION="3.9.6"
    cd /opt
    wget "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    tar -xzf "apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    ln -sf "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn
    echo "export M2_HOME=/opt/apache-maven-${MAVEN_VERSION}" >> /etc/profile.d/devops.sh
    echo "export PATH=\$M2_HOME/bin:\$PATH" >> /etc/profile.d/devops.sh
    rm -f "apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    cd -
}

mvn -version
print_success "Maven installed"

# ──────────────────────────────────────────────────────────────
# 5. DOCKER
# ──────────────────────────────────────────────────────────────
print_header "5/7 — Installing Docker"

yum install -y docker

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add jenkins user to docker group so Jenkins can run Docker commands
usermod -aG docker jenkins

print_success "Docker installed"
print_info "Jenkins user added to docker group (restart Jenkins later)"

# ──────────────────────────────────────────────────────────────
# 6. AWS CLI v2
# ──────────────────────────────────────────────────────────────
print_header "6/7 — Installing AWS CLI v2"

# Check if already installed
if command -v aws &> /dev/null; then
    print_info "AWS CLI already installed, upgrading..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -qo awscliv2.zip
    ./aws/install --update
else
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -qo awscliv2.zip
    ./aws/install
fi

rm -rf awscliv2.zip aws/

aws --version
print_success "AWS CLI v2 installed"

# ──────────────────────────────────────────────────────────────
# 7. KUBECTL + EKSCTL
# ──────────────────────────────────────────────────────────────
print_header "7/7 — Installing kubectl & eksctl"

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
kubectl version --client
print_success "kubectl installed"

# eksctl
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf "eksctl_$PLATFORM.tar.gz" -C /usr/local/bin
rm -f "eksctl_$PLATFORM.tar.gz"
eksctl version
print_success "eksctl installed"

# ──────────────────────────────────────────────────────────────
# RESTART JENKINS (to pick up docker group membership)
# ──────────────────────────────────────────────────────────────
print_header "Restarting Jenkins..."
systemctl restart jenkins
print_success "Jenkins restarted"

# ──────────────────────────────────────────────────────────────
# SOURCE ENVIRONMENT VARIABLES
# ──────────────────────────────────────────────────────────────
source /etc/profile.d/devops.sh 2>/dev/null || true

# ──────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉  ALL TOOLS INSTALLED SUCCESSFULLY!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Installed Tools:"
echo "  ─────────────────────────────────────────"
echo "  Java:    $(java -version 2>&1 | head -1)"
echo "  Maven:   $(mvn -version 2>&1 | head -1)"
echo "  Docker:  $(docker --version)"
echo "  AWS CLI: $(aws --version)"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1)"
echo "  eksctl:  $(eksctl version)"
echo "  Jenkins: Running on port 8080"
echo ""
echo -e "${YELLOW}  📌 NEXT STEPS:${NC}"
echo "  1. Access Jenkins: http://<EC2-PUBLIC-IP>:8080"
echo "  2. Get admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "  3. Complete Jenkins setup wizard"
echo "  4. Install required Jenkins plugins"
echo ""
echo -e "${YELLOW}  ⚠️  IMPORTANT:${NC}"
echo "  - Open port 8080 in your EC2 Security Group for Jenkins"
echo "  - Open port 80 if testing locally"
echo "  - Log out and back in for docker group to take effect"
echo ""
