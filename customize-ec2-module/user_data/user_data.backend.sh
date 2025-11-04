#!/bin/bash
set -euo pipefail
 
echo "==============================================="
echo " Backend Server Setup Script - Starting "
echo "==============================================="
 

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo " Cannot detect OS. Exiting..."
  exit 1
fi
 
DEVOPS_USER="devops"
JENKINS_USER="jenkins"
 
echo " Detected OS: $OS"
echo " DevOps User: $DEVOPS_USER"
echo " Jenkins User: $JENKINS_USER"
 

install_maven() {
  MAVEN_VERSION="3.8.9"
  MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"
 
  echo "[*] Installing Apache Maven ${MAVEN_VERSION}..."
 
  if command -v mvn >/dev/null 2>&1; then
    echo " Maven already installed: $(mvn -v | head -n 1)"
    return
  fi
 
  cd /tmp
  echo "Downloading Maven from: ${MAVEN_URL}"
  curl -fsSLO "${MAVEN_URL}"
 
  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"
 
  # Add environment variables permanently
  if ! grep -q "MAVEN_HOME" /etc/profile.d/maven.sh 2>/dev/null; then
    echo "export MAVEN_HOME=${MAVEN_DIR}" | sudo tee /etc/profile.d/maven.sh >/dev/null
    echo 'export PATH=$PATH:$MAVEN_HOME/bin' | sudo tee -a /etc/profile.d/maven.sh >/dev/null
    sudo chmod +x /etc/profile.d/maven.sh
  fi
 
  # Source for current session
  source /etc/profile.d/maven.sh
 
  echo " Maven installed successfully: $(mvn -v | head -n 1)"
}
 

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Installing Java 21, Docker, Git, and Maven on Ubuntu/Debian..."
 
  echo "[1/8] Updating packages..."
  sudo apt-get update -y
 
  echo "[2/8] Installing dependencies..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git
 
  echo "[3/8] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker
 
  echo "[4/8] Installing Maven..."
  install_maven
 
  echo "[5/8] Creating Jenkins user if not exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  else
    echo " Jenkins user already exists."
  fi
 
  echo "[6/8] Adding users to Docker group..."
  sudo usermod -aG docker "$DEVOPS_USER" || true
  sudo usermod -aG docker "$JENKINS_USER" || true
 
  echo "[7/8] Restarting Docker..."
  sudo systemctl restart docker
 
  echo "[8/8] Verifying installations..."
  java -version || echo " Java not found"
  docker --version || echo " Docker not found"
  git --version || echo " Git not found"
  mvn -v || echo " Maven not found"
 

elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Installing Java 21, Docker, Git, and Maven on Amazon Linux / RHEL / CentOS..."
 
  echo "[1/8] Updating packages..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi
 
  echo "[2/8] Installing dependencies..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y java-21-openjdk docker git curl wget
  else
    sudo yum install -y java-21-openjdk docker git curl wget
  fi
 
  echo "[3/8] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker
 
  echo "[4/8] Installing Maven..."
  install_maven
 
  echo "[5/8] Creating Jenkins user if not exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  else
    echo " Jenkins user already exists."
  fi
 
  echo "[6/8] Adding users to Docker group..."
  sudo usermod -aG docker "$DEVOPS_USER" || true
  sudo usermod -aG docker "$JENKINS_USER" || true
 
  echo "[7/8] Restarting Docker..."
  sudo systemctl restart docker
 
  echo "[8/8] Verifying installations..."
  java -version || echo " Java not found"
  docker --version || echo " Docker not found"
  git --version || echo " Git not found"
  mvn -v || echo " Maven not found"
 
else
  echo " Unsupported OS: $OS"
  exit 1
fi
 
# =====================================================================
# Final Output
# =====================================================================
echo "==============================================="
echo "  Backend Server Setup Completed Successfully "
echo "==============================================="
echo " Installed components:"
echo " - Java 21"
echo " - Docker (enabled & started)"
echo " - Git"
echo " - Maven 3.8.9"
echo " Docker group assigned to users: $DEVOPS_USER, $JENKINS_USER"
echo "==============================================="
 
 