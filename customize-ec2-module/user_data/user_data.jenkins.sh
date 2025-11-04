#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins_master_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==============================================="
echo " Jenkins Master Setup Script - Starting "
echo " Log file: $LOG_FILE"
echo "==============================================="

# -------------------------------------------------------
# Helper functions for consistent logging
# -------------------------------------------------------
log_info()  { echo -e "[INFO]  $*"; }
log_warn()  { echo -e "[WARN]  $*"; }
log_error() { echo -e "[ERROR] $*" >&2; }
log_success(){ echo -e "[SUCCESS] $*"; }

trap 'log_error " Script failed at line $LINENO. Check $LOG_FILE for details."' ERR

# -------------------------------------------------------
# Detect OS type
# -------------------------------------------------------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  log_error "Cannot detect OS. Exiting..."
  exit 1
fi
log_info "Detected OS: $OS"

# -------------------------------------------------------
# Function: Install AWS CLI v2
# -------------------------------------------------------
install_aws_cli() {
  log_info "Installing AWS CLI v2..."
  if command -v aws >/dev/null 2>&1; then
    log_success "AWS CLI already installed: $(aws --version)"
    return
  fi

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || {
    log_error "Failed to download AWS CLI package"; exit 1;
  }

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y unzip >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y unzip >/dev/null
  fi

  unzip -q awscliv2.zip
  sudo ./aws/install && rm -rf aws awscliv2.zip
  log_success "AWS CLI v2 installed: $(aws --version)"
}

# -------------------------------------------------------
# Function: Install Apache Maven (system-wide)
# -------------------------------------------------------
install_maven() {
  MAVEN_VERSION="3.8.9"
  MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_TAR="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_URL="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}"

  log_info "Installing Apache Maven ${MAVEN_VERSION}..."
  if command -v mvn >/dev/null 2>&1; then
    log_success "Maven already installed: $(mvn -v | head -n 1)"
    return
  fi

  cd /tmp
  curl -fsSLO "${MAVEN_URL}" || { log_error "Failed to download Maven"; exit 1; }
  sudo tar -xzf "${MAVEN_TAR}" -C /opt/ && rm -f "${MAVEN_TAR}"

  sudo tee /etc/profile.d/maven.sh >/dev/null <<EOF
export MAVEN_HOME=${MAVEN_DIR}
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF
  sudo chmod +x /etc/profile.d/maven.sh
  source /etc/profile.d/maven.sh
  sudo ln -sf ${MAVEN_DIR}/bin/mvn /usr/bin/mvn

  if command -v mvn >/dev/null 2>&1; then
    log_success "Maven installed successfully: $(mvn -v | head -n 1)"
  else
    log_error "Maven installation failed or PATH not updated."
  fi
}

# -------------------------------------------------------
# Function: Start and enable Jenkins
# -------------------------------------------------------
start_and_enable_jenkins() {
  log_info "Reloading systemd and starting Jenkins..."
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins || {
    log_error "Failed to start Jenkins service"; exit 1;
  }
  log_success "Jenkins service started successfully"
}

# =====================================================================
# Ubuntu / Debian Setup
# =====================================================================
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  log_info "Installing Jenkins on Ubuntu/Debian..."

  log_info "[1/9] Updating system packages..."
  sudo apt-get update -y && sudo apt-get upgrade -y && log_success "System updated successfully."

  log_info "[2/9] Installing dependencies (Java 21, Docker, Git)..."
  sudo apt-get install -y wget curl fontconfig openjdk-21-jdk docker.io git && log_success "Dependencies installed."

  log_info "[3/9] Installing AWS CLI..."
  install_aws_cli

  log_info "[4/9] Installing Maven..."
  install_maven

  log_info "[5/9] Adding Jenkins repository..."
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  log_success "Jenkins repository added."

  log_info "[6/9] Installing Jenkins..."
  sudo apt-get update -y && sudo apt-get install -y jenkins && log_success "Jenkins installed."

  log_info "[7/9] Enabling and starting Docker..."
  sudo systemctl enable docker && sudo systemctl start docker && log_success "Docker service running."

  log_info "[8/9] Adding Jenkins user to Docker group..."
  sudo usermod -aG docker jenkins && log_success "Jenkins user added to Docker group."

  log_info "[9/9] Starting Jenkins service..."
  start_and_enable_jenkins

# =====================================================================
# Amazon Linux / RHEL / CentOS Setup
# =====================================================================
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  log_info "Installing Jenkins on Amazon Linux / RHEL / CentOS..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi
  log_success "System packages updated."

  log_info "Adding Jenkins repository..."
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
  log_success "Jenkins repository added."

  log_info "Installing dependencies (Java 21, Docker, Git)..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y fontconfig java-21-openjdk docker git
  else
    sudo yum install -y fontconfig java-21-openjdk docker git
  fi
  log_success "Dependencies installed."

  log_info "Installing AWS CLI..."
  install_aws_cli

  log_info "Installing Maven..."
  install_maven

  log_info "Installing Jenkins..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jenkins
  else
    sudo yum install -y jenkins
  fi
  log_success "Jenkins installed successfully."

  log_info "Enabling and starting Docker..."
  sudo systemctl enable docker && sudo systemctl start docker && log_success "Docker service running."

  log_info "Adding Jenkins user to Docker group..."
  sudo usermod -aG docker jenkins && log_success "Jenkins user added to Docker group."

  log_info "Starting Jenkins service..."
  start_and_enable_jenkins

else
  log_error "Unsupported OS: $OS"
  exit 1
fi

# =====================================================================
# Final Output
# =====================================================================
echo
log_success "==============================================="
log_success " Jenkins Installation Completed Successfully!"
log_success "==============================================="
echo " Jenkins is running on: http://<EC2-Public-IP>:8080"
echo
mvn -v || log_warn "Maven not found or PATH not updated yet (try re-login)."
echo
log_info "Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || log_warn "Jenkins may still be initializing..."
echo "==============================================="
log_info "Setup log saved at: $LOG_FILE"