#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backend_server_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Backend Server Setup Script - Starting "
echo "==============================================="

# Detect OS type
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo " Cannot detect OS. Exiting..."
  exit 1
fi

DEVOPS_USER="devops"
JENKINS_USER="jenkins"
CURRENT_USER=$(whoami)

echo "Detected OS: $OS"
echo "DevOps User: $DEVOPS_USER"
echo "Jenkins User: $JENKINS_USER"
echo "Current User: $CURRENT_USER"

# -------------------------------
# Function: Install AWS CLI v2
# -------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI already installed: $(aws --version)"
    return
  fi
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  if [ ! -f awscliv2.zip ]; then
    echo "Failed to download AWS CLI"
    exit 1
  fi
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip >/dev/null
  else
    sudo yum install -y unzip >/dev/null || sudo dnf install -y unzip >/dev/null
  fi
  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf aws awscliv2.zip
  echo "✅ AWS CLI installed: $(aws --version)"
}

# -------------------------------
# Function: Install Maven
# -------------------------------
install_maven() {
  MAVEN_VERSION="3.8.9"
  MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

  echo "[*] Installing Apache Maven ${MAVEN_VERSION}..."
  if command -v mvn >/dev/null 2>&1; then
    echo "Maven already installed: $(mvn -v | head -n 1)"
    return
  fi

  cd /tmp
  echo "Downloading Maven from: ${MAVEN_URL}"
  curl -fsSLO "${MAVEN_URL}"

  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"

  # Permanent PATH setup
  if ! grep -q "MAVEN_HOME" /etc/profile.d/maven.sh 2>/dev/null; then
    echo "export MAVEN_HOME=${MAVEN_DIR}" | sudo tee /etc/profile.d/maven.sh >/dev/null
    echo 'export PATH=$PATH:$MAVEN_HOME/bin' | sudo tee -a /etc/profile.d/maven.sh >/dev/null
    sudo chmod +x /etc/profile.d/maven.sh
  fi

  source /etc/profile.d/maven.sh
  echo "✅ Maven installed: $(mvn -v | head -n 1)"
}

# -------------------------------
# Function: Install Dependencies
# -------------------------------
install_dependencies_ubuntu() {
  echo "[*] Updating system packages..."
  sudo apt-get update -y && sudo apt-get upgrade -y

  echo "[*] Installing Java 21, Docker, Git..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git

  echo "[*] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  install_maven
  install_aws_cli
}

install_dependencies_amzn() {
  echo "[*] Updating system packages..."
  if command -v dnf >/dev/null 2>&1; then sudo dnf upgrade -y; else sudo yum update -y; fi

  echo "[*] Installing Java 21, Docker, Git..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y java-21-openjdk docker git curl wget
  else
    sudo yum install -y java-21-openjdk docker git curl wget
  fi

  sudo systemctl enable docker
  sudo systemctl start docker

  install_maven
  install_aws_cli
}

# -------------------------------
# Function: Setup users and Docker access
# -------------------------------
setup_users_and_docker() {
  # Create Jenkins user if not exists
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo "Jenkins user created."
  fi

  # Add users to Docker group
  for user in "$DEVOPS_USER" "$JENKINS_USER" "$CURRENT_USER" ubuntu ec2-user; do
    if id "$user" &>/dev/null; then
      sudo usermod -aG docker "$user" || true
      echo "Added $user to Docker group."
    fi
  done

  sudo systemctl restart docker
}

# -------------------------------
# OS-based Installation
# -------------------------------
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  install_dependencies_ubuntu
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  install_dependencies_amzn
else
  echo "Unsupported OS: $OS"
  exit 1
fi

setup_users_and_docker

# -------------------------------
# Final Output
# -------------------------------
echo "==============================================="
echo " Backend Server Setup Completed Successfully "
echo "==============================================="
echo "Installed components:"
echo " - Java 21"
echo " - Docker (enabled & started)"
echo " - Git"
echo " - Maven 3.8.9"
echo " - AWS CLI v2"
echo "Docker group assigned to users: $DEVOPS_USER, $JENKINS_USER, $CURRENT_USER, ubuntu/ec2-user"
echo "==============================================="
