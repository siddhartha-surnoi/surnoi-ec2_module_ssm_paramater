#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backend_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Backend Environment Setup Script - Starting "
echo "==============================================="

# -------------------------------------------------------
# Detect OS type
# -------------------------------------------------------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo " Cannot detect OS. Exiting..."
  exit 1
fi

echo " Detected OS: $OS"

# -------------------------------------------------------
# Function: Install AWS CLI v2
# -------------------------------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  if command -v aws >/dev/null 2>&1; then
    echo " AWS CLI already installed: $(aws --version)"
    return
  fi

  echo "Downloading AWS CLI v2 package..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  if [ ! -f awscliv2.zip ]; then
    echo " Failed to download AWS CLI package"
    exit 1
  fi

  echo "Installing unzip..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y unzip >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y unzip >/dev/null
  fi

  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf aws awscliv2.zip
  echo "✅ AWS CLI v2 installed: $(aws --version)"
}

# -------------------------------------------------------
# Function: Install Apache Maven
# -------------------------------------------------------
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
  curl -fsSLO "${MAVEN_URL}" || { echo "❌ Failed to download Maven"; exit 1; }

  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"

  echo "Configuring Maven environment..."
  sudo tee /etc/profile.d/maven.sh >/dev/null <<EOF
export MAVEN_HOME=${MAVEN_DIR}
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF

  sudo chmod +x /etc/profile.d/maven.sh
  source /etc/profile.d/maven.sh

  sudo ln -sf ${MAVEN_DIR}/bin/mvn /usr/bin/mvn
  echo "✅ Maven installed successfully: $(mvn -v | head -n 1)"
}

# =====================================================================
# Ubuntu / Debian Setup
# =====================================================================
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Setting up backend environment on Ubuntu/Debian..."

  echo "[1/6] Updating system packages..."
  sudo apt-get update -y && sudo apt-get upgrade -y

  echo "[2/6] Installing dependencies (Java 21, Docker, Git)..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git

  echo "[3/6] Installing AWS CLI..."
  install_aws_cli

  echo "[4/6] Installing Maven..."
  install_maven

  echo "[5/6] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[6/6] Adding users (ubuntu/ec2-user) to Docker group..."
  CURRENT_USER=$(whoami)
  sudo usermod -aG docker "$CURRENT_USER"
  echo "✅ Added $CURRENT_USER to docker group"

# =====================================================================
# Amazon Linux / RHEL / CentOS Setup
# =====================================================================
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Setting up backend environment on Amazon Linux / RHEL / CentOS..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y fontconfig java-21-openjdk docker git
  else
    sudo yum install -y fontconfig java-21-openjdk docker git
  fi

  install_aws_cli
  install_maven

  sudo systemctl enable docker
  sudo systemctl start docker

  CURRENT_USER=$(whoami)
  sudo usermod -aG docker "$CURRENT_USER"
  echo "✅ Added $CURRENT_USER to docker group"
else
  echo " Unsupported OS: $OS"
  exit 1
fi

# =====================================================================
# Final Output
# =====================================================================
echo "==============================================="
echo " Backend Environment Setup Completed Successfully!"
echo "==============================================="
echo
echo " Java version:"
java -version
echo
echo " Maven version:"
mvn -v
echo
echo " Docker version:"
docker --version
echo
echo " AWS CLI version:"
aws --version
echo
echo "✅ You may need to re-login for Docker group changes to take effect."
echo "==============================================="
