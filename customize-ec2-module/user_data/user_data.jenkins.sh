#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins_master_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Jenkins Master Setup Script - Starting "
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
  echo " AWS CLI v2 installed: $(aws --version)"
}

# -------------------------------------------------------
# Function: Install Apache Maven (system-wide)
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
  echo "Downloading Maven from: ${MAVEN_URL}"
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

  # Add global symlink for all users
  sudo ln -sf ${MAVEN_DIR}/bin/mvn /usr/bin/mvn

  if command -v mvn >/dev/null 2>&1; then
    echo "✅ Maven installed successfully: $(mvn -v | head -n 1)"
  else
    echo "❌ Maven installation failed or PATH not updated."
  fi
}

# -------------------------------------------------------
# Function: Start and enable Jenkins
# -------------------------------------------------------
start_and_enable_jenkins() {
  echo " Reloading systemd and enabling Jenkins..."
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl start jenkins
  sudo systemctl restart jenkins
}

# =====================================================================
# Ubuntu / Debian Setup
# =====================================================================
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Installing Jenkins on Ubuntu/Debian..."

  echo "[1/9] Updating system packages..."
  sudo apt-get update -y && sudo apt-get upgrade -y

  echo "[2/9] Installing dependencies (Java 21, Docker, Git)..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git

  echo "[3/9] Installing AWS CLI..."
  install_aws_cli

  echo "[4/9] Installing Maven..."
  install_maven

  echo "[5/9] Adding Jenkins repository..."
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list >/dev/null

  echo "[6/9] Installing Jenkins..."
  sudo apt-get update -y
  sudo apt-get install -y jenkins

  echo "[7/9] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[8/9] Adding Jenkins user to Docker group..."
  sudo usermod -aG docker jenkins

  echo "[9/9] Starting Jenkins service..."
  start_and_enable_jenkins

# =====================================================================
# Amazon Linux / RHEL / CentOS Setup
# =====================================================================
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Installing Jenkins on Amazon Linux / RHEL / CentOS..."

  echo "[1/9] Updating system packages..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi

  echo "[2/9] Adding Jenkins repository..."
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

  echo "[3/9] Installing dependencies (Java 21, Docker, Git)..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y fontconfig java-21-openjdk docker git
  else
    sudo yum install -y fontconfig java-21-openjdk docker git
  fi

  echo "[4/9] Installing AWS CLI..."
  install_aws_cli

  echo "[5/9] Installing Maven..."
  install_maven

  echo "[6/9] Installing Jenkins..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jenkins
  else
    sudo yum install -y jenkins
  fi

  echo "[7/9] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[8/9] Adding Jenkins user to Docker group..."
  sudo usermod -aG docker jenkins

  echo "[9/9] Enabling and restarting Jenkins service..."
  start_and_enable_jenkins

else
  echo " Unsupported OS: $OS"
  exit 1
fi

# =====================================================================
# Final Output
# =====================================================================
echo "==============================================="
echo " Jenkins Installation Completed Successfully!"
echo "==============================================="
echo " Jenkins is running on: http://<EC2-Public-IP>:8080"
echo
echo " Maven version check:"
mvn -v || echo " Maven not found or PATH not updated yet (try re-login)."
echo
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || echo "Jenkins may still be initializing..."
echo "==============================================="
