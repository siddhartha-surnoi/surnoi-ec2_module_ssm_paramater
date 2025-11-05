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
  echo " Cannot detect OS. Exiting..."
  exit 1
fi

DEVOPS_USER="devops"
JENKINS_USER="jenkins"
CURRENT_USER=$(whoami)

echo " Detected OS: $OS"
echo " DevOps User: $DEVOPS_USER"
echo " Jenkins User: $JENKINS_USER"
echo " Current User: $CURRENT_USER"

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
    echo "❌ Failed to download AWS CLI package"
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
# Function: Install Apache Maven 3.9.8
# -------------------------------------------------------
install_maven() {
  MAVEN_VERSION="3.9.8"
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
# Function: Configure Docker group access
# -------------------------------------------------------
configure_docker_access() {
  echo "[*] Configuring Docker access for users..."

  if ! getent group docker >/dev/null; then
    sudo groupadd docker
  fi

  for user in "$DEVOPS_USER" "$JENKINS_USER" ec2-user ubuntu "$CURRENT_USER"; do
    if id "$user" &>/dev/null; then
      sudo usermod -aG docker "$user"
      echo " Added $user to docker group."
    fi
  done

  sudo systemctl restart docker
  echo "✅ Docker group configured successfully."
}

# -------------------------------------------------------
# Ubuntu/Debian Setup
# -------------------------------------------------------
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Installing Java 21, Docker, Git, Maven, and AWS CLI on Ubuntu/Debian..."

  echo "[1/9] Updating packages..."
  sudo apt-get update -y

  echo "[2/9] Installing dependencies..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git

  echo "[3/9] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[4/9] Installing Maven..."
  install_maven

  echo "[5/9] Installing AWS CLI..."
  install_aws_cli

  echo "[6/9] Creating Jenkins user if not exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  else
    echo " Jenkins user already exists."
  fi

  echo "[7/9] Configuring Docker group access..."
  configure_docker_access

  echo "[8/9] Restarting Docker..."
  sudo systemctl restart docker

  echo "[9/9] Verifying installations..."
  java -version
  docker --version
  git --version
  mvn -v
  aws --version

# -------------------------------------------------------
# Amazon Linux / RHEL / CentOS Setup
# -------------------------------------------------------
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Installing Java 21, Docker, Git, Maven, and AWS CLI on Amazon Linux / RHEL / CentOS..."

  echo "[1/9] Updating packages..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi

  echo "[2/9] Installing dependencies..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y java-21-openjdk docker git curl wget
  else
    sudo yum install -y java-21-openjdk docker git curl wget
  fi

  echo "[3/9] Enabling and starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo "[4/9] Installing Maven..."
  install_maven

  echo "[5/9] Installing AWS CLI..."
  install_aws_cli

  echo "[6/9] Creating Jenkins user if not exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  else
    echo " Jenkins user already exists."
  fi

  echo "[7/9] Configuring Docker group access..."
  configure_docker_access

  echo "[8/9] Restarting Docker..."
  sudo systemctl restart docker

  echo "[9/9] Verifying installations..."
  java -version
  docker --version
  git --version
  mvn -v
  aws --version

else
  echo " Unsupported OS: $OS"
  exit 1
fi

# =====================================================================
# Final Output Summary
# =====================================================================
echo "==============================================="
echo " ✅ Backend Server Setup Completed Successfully "
echo "==============================================="
echo " Installed Components & Versions:"
java -version 2>&1 | head -n 1
docker --version
git --version
mvn -v | head -n 1
aws --version
echo
echo " Docker access granted to users:"
for user in "$DEVOPS_USER" "$JENKINS_USER" ec2-user ubuntu "$CURRENT_USER"; do
  if id "$user" &>/dev/null && id "$user" | grep -q docker; then
    echo "  - $user ✅"
  else
    echo "  - $user ❌ (not found or not in docker group)"
  fi
done
echo "==============================================="
