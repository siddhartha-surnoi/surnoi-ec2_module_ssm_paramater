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
# Function: Wait for network
# -------------------------------------------------------
wait_for_network() {
  echo "[*] Waiting for network..."
  until ping -c1 8.8.8.8 >/dev/null 2>&1; do
    echo " Network not ready, waiting 5s..."
    sleep 5
  done
  echo "[*] Network is ready!"
}

wait_for_network

# -------------------------------------------------------
# Function: Wait for apt/dpkg lock (Ubuntu/Debian)
# -------------------------------------------------------
wait_for_apt_lock() {
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo "[*] Checking for other package managers..."
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
      echo " Waiting for other package managers to finish..."
      sleep 5
    done
  fi
}

# -------------------------------------------------------
# Function: Retry downloads
# -------------------------------------------------------
retry_curl() {
  local url="$1"
  local dest="$2"
  local n=0
  until [ $n -ge 5 ]; do
    curl -fsSL "$url" -o "$dest" && break
    n=$((n+1))
    echo " Retry $n for $url"
    sleep 5
  done
  if [ $n -ge 5 ]; then
    echo "❌ Failed to download $url after 5 attempts"
    exit 1
  fi
}

# -------------------------------------------------------
# Function: Install AWS CLI v2
# -------------------------------------------------------
install_aws_cli() {
  echo "[*] Installing AWS CLI v2..."
  if command -v aws >/dev/null 2>&1; then
    echo " AWS CLI already installed: $(aws --version)"
    return
  fi

  retry_curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "/tmp/awscliv2.zip"

  if command -v apt-get >/dev/null 2>&1; then
    wait_for_apt_lock
    sudo apt-get install -y unzip >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y unzip >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y unzip >/dev/null
  fi

  cd /tmp
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
  retry_curl "${MAVEN_URL}" "/tmp/${MAVEN_TAR}"

  sudo tar -xzf "/tmp/${MAVEN_TAR}" -C /opt/
  rm -f "/tmp/${MAVEN_TAR}"

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

# -------------------------------------------------------
# Function: Start and enable Jenkins
# -------------------------------------------------------
start_and_enable_jenkins() {
  echo " Reloading systemd and enabling Jenkins..."
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
}

# =====================================================================
# Ubuntu / Debian Setup
# =====================================================================
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Installing Jenkins on Ubuntu/Debian..."

  echo "[1/9] Updating system packages..."
  wait_for_apt_lock
  sudo apt-get update -y
  wait_for_apt_lock
  sudo apt-get upgrade -y
  sudo dpkg --configure -a || true

  echo "[2/9] Installing dependencies (Java 21, Docker, Git)..."
  wait_for_apt_lock
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git || true

  echo "[3/9] Installing AWS CLI..."
  install_aws_cli

  echo "[4/9] Installing Maven..."
  install_maven

  echo "[5/9] Adding Jenkins repository..."
  retry_curl "https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key" "/tmp/jenkins.key"
  sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null < /tmp/jenkins.key
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  wait_for_apt_lock
  sudo apt-get update -y

  echo "[6/9] Installing Jenkins..."
  wait_for_apt_lock
  sudo apt-get install -y jenkins || { echo "❌ Jenkins installation failed"; exit 1; }

  echo "[7/9] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[8/9] Adding Jenkins user to Docker group..."
  if id "jenkins" &>/dev/null; then
    sudo usermod -aG docker jenkins
  else
    echo "⚠️ Jenkins user not found — creating it manually..."
    sudo useradd -m -s /bin/bash jenkins
    sudo usermod -aG docker jenkins
  fi

  echo "[9/9] Starting Jenkins service..."
  start_and_enable_jenkins

# =====================================================================
# Amazon Linux / RHEL / CentOS Setup
# =====================================================================
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Installing Jenkins on Amazon Linux / RHEL / CentOS..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
    sudo dnf install -y fontconfig java-21-openjdk docker git unzip wget curl || true
  else
    sudo yum update -y
    sudo yum install -y fontconfig java-21-openjdk docker git unzip wget curl || true
  fi

  install_aws_cli
  install_maven

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jenkins || true
  else
    sudo yum install -y jenkins || true
  fi

  sudo systemctl enable docker
  sudo systemctl start docker

  if id "jenkins" &>/dev/null; then
    sudo usermod -aG docker jenkins
  fi

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
echo " Jenkins Service Status:"
sudo systemctl status jenkins --no-pager | head -n 10
echo
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins may still be initializing..."
echo "==============================================="
