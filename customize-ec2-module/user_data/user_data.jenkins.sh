#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins_master_setup.log"
VERSION_LOG="/var/log/jenkins_master_versions.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Jenkins Master Setup Script - Starting "
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
# Functions
# -------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  command -v aws >/dev/null 2>&1 && { echo " AWS CLI already installed: $(aws --version)"; return; }
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  [[ ! -f /tmp/awscliv2.zip ]] && { echo "❌ Failed to download AWS CLI"; exit 1; }
  
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip >/dev/null
  else
    sudo yum install -y unzip >/dev/null || sudo dnf install -y unzip >/dev/null
  fi

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
  command -v mvn >/dev/null 2>&1 && { echo " Maven already installed: $(mvn -v | head -n1)"; return; }

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
  echo "✅ Docker & Compose installed"
}

install_dependencies() {
  echo "[*] Installing dependencies: Git, Curl, Wget, Fontconfig, Java 21..."
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y git curl wget fontconfig openjdk-21-jdk unzip
  else
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf upgrade -y
      sudo dnf install -y git curl wget fontconfig java-21-openjdk unzip
    else
      sudo yum update -y
      sudo yum install -y git curl wget fontconfig java-21-openjdk unzip
    fi
  fi
}

install_jenkins() {
  echo "[*] Installing Jenkins..."
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
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
}

add_users_to_docker() {
  echo "[*] Adding users to Docker group..."
  for u in "${USERS_TO_ADD[@]}"; do
    id "$u" &>/dev/null && sudo usermod -aG docker "$u"
  done
}

start_and_enable_jenkins() {
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
}

# -------------------------------
# Execute installations
# -------------------------------
install_dependencies
install_aws_cli
install_maven
install_docker
install_jenkins
add_users_to_docker
start_and_enable_jenkins

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
echo " Jenkins Master Setup Completed Successfully!"
echo " Jenkins URL: http://<EC2-Public-IP>:8080"
echo " Versions logged in $VERSION_LOG"
echo " Logs: $LOG_FILE"
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins may still be initializing..."
echo "==============================================="
