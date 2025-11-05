#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/backend_setup.log"
VERSION_LOG="/var/log/backend_versions.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Backend Server Setup Script - Starting "
echo "==============================================="

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Cannot detect OS. Exiting..."
  exit 1
fi

CURRENT_USER=$(whoami)
USERS_TO_ADD=("$CURRENT_USER" "ubuntu" "ec2-user")

echo "Detected OS: $OS"
echo "Current User: $CURRENT_USER"

# -------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  command -v aws >/dev/null 2>&1 && { echo "AWS CLI already installed: $(aws --version)"; return; }
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  if [[ ! -f /tmp/awscliv2.zip ]]; then echo "❌ Failed to download AWS CLI"; exit 1; fi
  if command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y unzip; else sudo yum install -y unzip || sudo dnf install -y unzip; fi
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
  echo "✅ AWS CLI v2 installed: $(aws --version)"
}

install_maven() {
  MAVEN_VERSION="3.9.11"
  MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

  echo "[*] Installing Apache Maven ${MAVEN_VERSION}..."
  command -v mvn >/dev/null 2>&1 && { echo "Maven already installed: $(mvn -v | head -n1)"; return; }

  cd /tmp
  curl -fsSLO "${MAVEN_URL}" || { echo "❌ Failed to download Maven"; exit 1; }
  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"

  sudo tee /etc/profile.d/maven.sh >/dev/null <<EOF
export MAVEN_HOME=${MAVEN_DIR}
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF

  sudo chmod +x /etc/profile.d/maven.sh
  source /etc/profile.d/maven.sh
  sudo ln -sf ${MAVEN_DIR}/bin/mvn /usr/bin/mvn

  echo "✅ Maven installed: $(mvn -v | head -n1)"
}

install_docker() {
  echo "[*] Installing Docker & Docker Compose plugin..."
  sudo rm -f /usr/local/bin/docker-compose
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y docker.io docker-compose-plugin
  else
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y docker docker-compose-plugin
    else
      sudo yum install -y docker docker-compose-plugin
    fi
  fi
  sudo systemctl enable docker
  sudo systemctl start docker
}

install_dependencies() {
  echo "[*] Installing Git, Curl, Wget, Fontconfig, Java 21..."
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get install -y git curl wget fontconfig openjdk-21-jdk unzip
  else
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y git curl wget fontconfig java-21-openjdk unzip
    else
      sudo yum install -y git curl wget fontconfig java-21-openjdk unzip
    fi
  fi
}

add_users_to_docker() {
  echo "[*] Adding users to Docker group..."
  for u in "${USERS_TO_ADD[@]}"; do
    id "$u" &>/dev/null && sudo usermod -aG docker "$u"
  done
}

# -------------------------------
# Execute installations
# -------------------------------
install_dependencies
install_aws_cli
install_maven
install_docker
add_users_to_docker

# -------------------------------
# Verification
# -------------------------------
echo "[*] Verifying installed versions..." | tee "$VERSION_LOG"
java -version 2>&1 | tee -a "$VERSION_LOG"
docker --version 2>&1 | tee -a "$VERSION_LOG"
docker compose version 2>&1 | tee -a "$VERSION_LOG"
git --version 2>&1 | tee -a "$VERSION_LOG"
mvn -v 2>&1 | tee -a "$VERSION_LOG"
aws --version 2>&1 | tee -a "$VERSION_LOG"

echo "[*] Docker hello-world test..."
sudo docker run --rm hello-world || echo "⚠️ Docker test failed"

echo "==============================================="
echo " Backend Server Setup Completed Successfully!"
echo " Logs: $LOG_FILE"
echo " Versions: $VERSION_LOG"
echo " Docker users: ${USERS_TO_ADD[*]}"
echo "==============================================="
