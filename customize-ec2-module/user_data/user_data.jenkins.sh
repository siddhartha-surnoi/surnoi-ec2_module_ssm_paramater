#!/bin/bash
set -euo pipefail

# -----------------------------
# Logging
# -----------------------------
LOG_FILE="/var/log/jenkins_master_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Jenkins + Backend Setup Script - Starting "
echo "==============================================="

# -----------------------------
# Detect OS type
# -----------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. Exiting..."
    exit 1
fi

DEVOPS_USER="devops"
JENKINS_USER="jenkins"

echo "Detected OS: $OS"
echo "DevOps User: $DEVOPS_USER"
echo "Jenkins User: $JENKINS_USER"

# -----------------------------
# Function: Install AWS CLI v2
# -----------------------------
install_aws_cli() {
    if command -v aws >/dev/null 2>&1; then
        echo "AWS CLI already installed: $(aws --version)"
        return
    fi
    echo "[*] Installing AWS CLI v2..."
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed: $(aws --version)"
}

# -----------------------------
# Function: Install Apache Maven
# -----------------------------
install_maven() {
    MAVEN_VERSION="3.9.11"
    MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
    MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

    if command -v mvn >/dev/null 2>&1; then
        echo "Maven already installed: $(mvn -v | head -n1)"
        return
    fi

    echo "[*] Installing Apache Maven ${MAVEN_VERSION}..."
    curl -fsSL "${MAVEN_URL}" -o "/tmp/${MAVEN_TAR}"
    sudo tar -xzf "/tmp/${MAVEN_TAR}" -C /opt/
    rm -f "/tmp/${MAVEN_TAR}"

    # Environment variables
    if [ ! -f /etc/profile.d/maven.sh ]; then
        echo "export MAVEN_HOME=${MAVEN_DIR}" | sudo tee /etc/profile.d/maven.sh >/dev/null
        echo 'export PATH=$PATH:$MAVEN_HOME/bin' | sudo tee -a /etc/profile.d/maven.sh >/dev/null
        sudo chmod +x /etc/profile.d/maven.sh
    fi
    source /etc/profile.d/maven.sh
    echo "Maven installed: $(mvn -v | head -n1)"
}

# -----------------------------
# Function: Install Java 21
# -----------------------------
install_java() {
    if command -v java >/dev/null 2>&1; then
        echo "Java already installed: $(java -version 2>&1 | head -n1)"
        return
    fi

    echo "[*] Installing Java 21..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get install -y openjdk-21-jdk
    else
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y java-21-openjdk
        else
            sudo yum install -y java-21-openjdk
        fi
    fi
    java -version
}

# -----------------------------
# Function: Install Docker & Compose
# -----------------------------
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo "Docker already installed: $(docker --version)"
    else
        echo "[*] Installing Docker..."
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            sudo apt-get install -y docker.io docker-compose-plugin
        else
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y docker docker-compose-plugin
            else
                sudo yum install -y docker docker-compose-plugin
            fi
        fi
    fi

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$DEVOPS_USER" || true
    sudo usermod -aG docker "$JENKINS_USER" || true
    echo "Docker installed: $(docker --version)"
    echo "Docker Compose plugin version: $(docker compose version)"
}

# -----------------------------
# Function: Install Git
# -----------------------------
install_git() {
    if command -v git >/dev/null 2>&1; then
        echo "Git already installed: $(git --version)"
        return
    fi
    echo "[*] Installing Git..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get install -y git
    else
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y git
        else
            sudo yum install -y git
        fi
    fi
    git --version
}

# -----------------------------
# Function: Create Jenkins user
# -----------------------------
create_jenkins_user() {
    if ! id "$JENKINS_USER" &>/dev/null; then
        sudo useradd -m -s /bin/bash "$JENKINS_USER"
        echo "Jenkins user created."
    else
        echo "Jenkins user already exists."
    fi
}

# -----------------------------
# Function: Install Jenkins
# -----------------------------
install_jenkins() {
    echo "[*] Installing Jenkins..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
        echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
        sudo apt-get update -y
        sudo apt-get install -y jenkins
    else
        sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y jenkins
        else
            sudo yum install -y jenkins
        fi
    fi

    sudo systemctl enable jenkins
    sudo systemctl start jenkins
    sudo usermod -aG docker jenkins || true
    echo "Jenkins installed and running: $(systemctl is-active jenkins)"
}

# -----------------------------
# Main Flow
# -----------------------------
echo "[1/8] Updating system packages..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y && sudo apt-get upgrade -y
else
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf upgrade -y
    else
        sudo yum update -y
    fi
fi

install_aws_cli
install_java
install_git
install_docker
install_maven
create_jenkins_user
install_jenkins

# -----------------------------
# Final Output
# -----------------------------
echo "==============================================="
echo " Jenkins + Backend Setup Completed Successfully! "
echo "==============================================="
echo "Installed components:"
echo " - Java 21"
echo " - Maven 3.9.11"
echo " - Docker & Docker Compose plugin"
echo " - Git"
echo " - AWS CLI v2"
echo " - Jenkins (running on port 8080)"
echo
echo "Users in Docker group: $DEVOPS_USER, $JENKINS_USER"
echo
echo "Jenkins Service Status:"
sudo systemctl status jenkins --no-pager | head -n 10
echo
echo "Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins still initializing..."
echo
echo "Login URL: http://<EC2-Public-IP>:8080"
echo "==============================================="
echo "All logs saved to: $LOG_FILE"
