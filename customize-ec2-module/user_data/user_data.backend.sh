#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backend_setup.log"
VERSION_LOG="/var/log/backend_versions.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Backend Server Setup Script - Starting "
echo "==============================================="

# -------------------------------
# Detect OS
# -------------------------------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Cannot detect OS. Exiting..."
  exit 1
fi

CURRENT_USER=$(whoami)
USERS_TO_ADD=("jenkins" "$CURRENT_USER" "ubuntu" "ec2-user")

echo "Detected OS: $OS"
echo "Current User: $CURRENT_USER"

# -------------------------------
# Install Maven 3.9.11
# -------------------------------
install_maven() {
  MAVEN_VERSION="3.9.11"
  MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

  echo "[*] Installing Apache Maven ${MAVEN_VERSION}..."
  if command -v mvn >/dev/null 2>&1; then
    echo " Maven already installed: $(mvn -v | head -n 1)"
    return
  fi

  cd /tmp
  curl -fsSLO "${MAVEN_URL}"
  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"

  # Permanent environment variables
  if ! grep -q "MAVEN_HOME" /etc/profile.d/maven.sh 2>/dev/null; then
    echo "export MAVEN_HOME=${MAVEN_DIR}" | sudo tee /etc/profile.d/maven.sh >/dev/null
    echo 'export PATH=$PATH:$MAVEN_HOME/bin' | sudo tee -a /etc/profile.d/maven.sh >/dev/null
    sudo chmod +x /etc/profile.d/maven.sh
  fi
  source /etc/profile.d/maven.sh
  echo " Maven installed successfully: $(mvn -v | head -n 1)"
}

# -------------------------------
# Install AWS CLI v2
# -------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI..."
  if command -v aws >/dev/null 2>&1; then
    echo " AWS CLI already installed: $(aws --version)"
    return
  fi
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
  echo " AWS CLI installed successfully: $(aws --version)"
}

# -------------------------------
# Install Docker & Docker Compose
# -------------------------------
install_docker() {
  echo "[*] Installing Docker & Docker Compose..."
  if command -v docker >/dev/null 2>&1; then
    echo " Docker already installed: $(docker --version)"
  else
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
      sudo apt-get install -y docker.io
    else
      if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y docker
      else
        sudo yum install -y docker
      fi
    fi
  fi

  sudo systemctl enable docker
  sudo systemctl start docker

  # Docker Compose v2
  if ! command -v docker-compose >/dev/null 2>&1; then
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.2/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi

  echo " Docker & Docker Compose installed successfully"
}

# -------------------------------
# Install dependencies
# -------------------------------
install_dependencies() {
  echo "[*] Installing dependencies: git, curl, wget, fontconfig, Java 21..."
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y git curl wget fontconfig openjdk-21-jdk unzip
  else
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf upgrade -y
      sudo dnf install -y git curl wget fontconfig java-21-openjdk unzip
    else
      sudo yum upgrade -y
      sudo yum install -y git curl wget fontconfig java-21-openjdk unzip
    fi
  fi
}

# -------------------------------
# Add users to Docker group
# -------------------------------
add_users_to_docker() {
  echo "[*] Adding users to Docker group..."
  for u in "${USERS_TO_ADD[@]}"; do
    if id "$u" &>/dev/null; then
      sudo usermod -aG docker "$u"
      echo " User $u added to Docker group"
    fi
  done
}

# -------------------------------
# Verification and Logging
# -------------------------------
verify_installations() {
  echo "[*] Verifying installations..."
  echo "==== Installed Versions ====" > "$VERSION_LOG"
  java -version 2>&1 | tee -a "$VERSION_LOG"
  docker --version 2>&1 | tee -a "$VERSION_LOG"
  docker-compose --version 2>&1 | tee -a "$VERSION_LOG"
  git --version 2>&1 | tee -a "$VERSION_LOG"
  mvn -v 2>&1 | tee -a "$VERSION_LOG"
  aws --version 2>&1 | tee -a "$VERSION_LOG"
  echo "All installation versions logged in $VERSION_LOG"
}

# -------------------------------
# Main Script Execution
# -------------------------------
install_dependencies
install_maven
install_aws_cli
install_docker
add_users_to_docker
verify_installations

echo "==============================================="
echo "  Backend Server Setup Completed Successfully "
echo "==============================================="
echo " Installed components:"
echo " - Java 21"
echo " - Maven 3.9.11"
echo " - AWS CLI v2"
echo " - Docker & Docker Compose"
echo " - Git"
echo " Docker group access granted to: ${USERS_TO_ADD[*]}"
echo " Logs: $LOG_FILE"
echo " Versions logged: $VERSION_LOG"
echo "==============================================="
