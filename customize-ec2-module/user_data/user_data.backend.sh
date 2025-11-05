#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backend_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Backend Server Setup Script - Starting "
echo "==============================================="

# -------------------------------------------------------
# Detect OS type
# -------------------------------------------------------
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

# -------------------------------------------------------
# Function: Install AWS CLI v2
# -------------------------------------------------------
install_aws_cli() {
    if command -v aws >/dev/null 2>&1; then
        echo "AWS CLI already installed: $(aws --version)"
        return
    fi
    echo "[*] Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed: $(aws --version)"
}

# -------------------------------------------------------
# Function: Install Apache Maven
# -------------------------------------------------------
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

# -------------------------------------------------------
# Function: Install Java 21
# -------------------------------------------------------
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

# -------------------------------------------------------
# Function: Install Docker & Docker Compose Plugin
# -------------------------------------------------------
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo "Docker already installed: $(docker --version)"
    else
        echo "[*] Installing Docker..."
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            sudo apt-get install -y docker.io
            sudo apt-get install -y docker-compose-plugin
        else
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y docker
                sudo dnf install -y docker-compose-plugin
            else
                sudo yum install -y docker
                sudo yum install -y docker-compose-plugin
            fi
        fi
    fi

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$DEVOPS_USER" || true
    sudo usermod -aG docker "$JENKINS_USER" || true
    echo "Docker installed and running: $(docker --version)"
    echo "Docker Compose plugin version: $(docker compose version)"
}

# -------------------------------------------------------
# Function: Install Git
# -------------------------------------------------------
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

# -------------------------------------------------------
# Function: Create Jenkins user if missing
# -------------------------------------------------------
create_jenkins_user() {
    if ! id "$JENKINS_USER" &>/dev/null; then
        sudo useradd -m -s /bin/bash "$JENKINS_USER"
        echo "Jenkins user created."
    else
        echo "Jenkins user already exists."
    fi
}

# -------------------------------------------------------
# Main Installation Flow
# -------------------------------------------------------
echo "[1/8] Updating package repositories..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
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

echo "==============================================="
echo "  Backend Server Setup Completed Successfully "
echo "==============================================="
echo "Installed components:"
echo " - Java 21"
echo " - Docker & Docker Compose plugin"
echo " - Git"
echo " - Maven 3.9.11"
echo " - AWS CLI v2"
echo "Docker group assigned to users: $DEVOPS_USER, $JENKINS_USER"
echo "==============================================="
