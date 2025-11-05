#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins_master_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Jenkins Master Setup Script - Starting "
echo "==============================================="

# Detect OS type
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Cannot detect OS. Exiting..."
  exit 1
fi
CURRENT_USER=$(whoami)
echo "Detected OS: $OS"
echo "Current User: $CURRENT_USER"

# Function: Install AWS CLI v2
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

# Function: Install Apache Maven
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
  echo "✅ Maven installed: $(mvn -v | head -n 1)"
}

# Function: Install Docker Compose
install_docker_compose() {
  echo "[*] Installing Docker Compose..."
  if command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose already installed: $(docker-compose --version)"
    return
  fi
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
  sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo "✅ Docker Compose installed: $(docker-compose --version)"
}

# Function: Configure Docker permissions
configure_docker_access() {
  echo "[*] Configuring Docker group..."
  if ! getent group docker >/dev/null; then sudo groupadd docker; fi
  for user in jenkins ubuntu ec2-user "$CURRENT_USER"; do
    if id "$user" &>/dev/null; then
      sudo usermod -aG docker "$user"
      echo "Added $user to Docker group."
    fi
  done
  sudo systemctl enable docker
  sudo systemctl restart docker
}

# Function: Start Jenkins service
start_jenkins() {
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
}

# Ubuntu/Debian Setup
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  sudo apt-get update -y
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git
  install_aws_cli
  install_maven
  install_docker_compose
  configure_docker_access
  # Jenkins
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y jenkins
  start_jenkins

# Amazon Linux / RHEL / CentOS Setup
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  if command -v dnf >/dev/null 2>&1; then sudo dnf upgrade -y; else sudo yum update -y; fi
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y fontconfig java-21-openjdk docker git
  else
    sudo yum install -y fontconfig java-21-openjdk docker git
  fi
  install_aws_cli
  install_maven
  install_docker_compose
  configure_docker_access
  if command -v dnf >/dev/null 2>&1; then sudo dnf install -y jenkins; else sudo yum install -y jenkins; fi
  start_jenkins
else
  echo "Unsupported OS: $OS"
  exit 1
fi

# Final Output
echo "==============================================="
echo " Jenkins Setup Completed Successfully!"
echo " Jenkins URL: http://<EC2-Public-IP>:8080"
echo " Installed Components: Java 21, Git, Maven, Docker, Docker Compose, AWS CLI, Jenkins"
echo " Docker access granted to: jenkins, ubuntu, ec2-user, $CURRENT_USER"
echo " Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins is initializing..."
echo "==============================================="
