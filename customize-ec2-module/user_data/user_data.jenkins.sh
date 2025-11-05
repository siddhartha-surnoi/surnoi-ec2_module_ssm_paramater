#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins_master_setup.log"
VERSION_LOG="/var/log/backend_versions.log"
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
# Install AWS CLI v2
# -------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  if command -v aws >/dev/null 2>&1; then
    echo " AWS CLI already installed: $(aws --version)"
    return
  fi

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  if [[ ! -f /tmp/awscliv2.zip ]]; then
    echo "❌ Failed to download AWS CLI"
    exit 1
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y unzip >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y unzip >/dev/null
  fi

  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
  echo "✅ AWS CLI v2 installed: $(aws --version)"
}

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
  curl -fsSLO "${MAVEN_URL}" || { echo "❌ Failed to download Maven"; exit 1; }
  sudo tar -xzf "${MAVEN_TAR}" -C /opt/
  rm -f "${MAVEN_TAR}"

  # Permanent environment variables
  sudo tee /etc/profile.d/maven.sh >/dev/null <<EOF
export MAVEN_HOME=${MAVEN_DIR}
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF
  sudo chmod +x /etc/profile.d/maven.sh
  source /etc/profile.d/maven.sh

  sudo ln -sf ${MAVEN_DIR}/bin/mvn /usr/bin/mvn
  echo "✅ Maven installed successfully: $(mvn -v | head -n 1)"
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
# Install dependencies
# -------------------------------
install_dependencies() {
  echo "[*] Installing dependencies: git, curl, wget, fontconfig, Java 21..."
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y git curl wget fontconfig openjdk-21-jdk docker.io unzip
  else
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf upgrade -y
      sudo dnf install -y git curl wget fontconfig java-21-openjdk docker unzip
    else
      sudo yum update -y
      sudo yum install -y git curl wget fontconfig java-21-openjdk docker unzip
    fi
  fi
}

# -------------------------------
# Start & Enable Jenkins
# -------------------------------
start_and_enable_jenkins() {
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
}

# -------------------------------
# OS-specific Jenkins Installation
# -------------------------------
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Installing Jenkins on Ubuntu/Debian..."
  sudo apt-get update -y && sudo apt-get upgrade -y
  install_dependencies
  install_aws_cli
  install_maven

  echo "[*] Adding Jenkins repository..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y jenkins || { echo "❌ Jenkins installation failed"; exit 1; }

elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Installing Jenkins on Amazon Linux / RHEL / CentOS..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi

  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
  install_dependencies
  install_aws_cli
  install_maven

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jenkins
  else
    sudo yum install -y jenkins
  fi

else
  echo " Unsupported OS: $OS"
  exit 1
fi

# -------------------------------
# Docker & Jenkins user setup
# -------------------------------
sudo systemctl enable docker
sudo systemctl start docker
add_users_to_docker
start_and_enable_jenkins

# -------------------------------
# Verification & Logging
# -------------------------------
echo "[*] Verifying installations..."
echo "==== Installed Versions ====" > "$VERSION_LOG"
java -version 2>&1 | tee -a "$VERSION_LOG"
docker --version 2>&1 | tee -a "$VERSION_LOG"
git --version 2>&1 | tee -a "$VERSION_LOG"
mvn -v 2>&1 | tee -a "$VERSION_LOG"
aws --version 2>&1 | tee -a "$VERSION_LOG"
docker-compose --version 2>/dev/null || echo "docker-compose not installed" >> "$VERSION_LOG"

# -------------------------------
# Final Output
# -------------------------------
echo "==============================================="
echo " Jenkins Master Setup Completed Successfully!"
echo "==============================================="
echo " Jenkins URL: http://<EC2-Public-IP>:8080"
echo
echo " Maven version check:"
mvn -v || echo " Maven not found or PATH not updated (try re-login)"
echo
echo " Jenkins Service Status:"
sudo systemctl status jenkins --no-pager | head -n 10
echo
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins may still be initializing..."
echo
echo " Versions logged in $VERSION_LOG"
echo " Logs: $LOG_FILE"
echo "==============================================="
