#!/bin/bash
set -euo pipefail

echo "==============================================="
echo "  AIML Environment Setup Script Starting..."
echo "==============================================="

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo " Cannot detect OS. Exiting..."
  exit 1
fi

DEVOPS_USER="devops"
JENKINS_USER="jenkins"

echo " Detected OS: $OS"
echo " Users: $DEVOPS_USER, $JENKINS_USER"

# =====================================================================
# Ubuntu / Debian Setup
# =====================================================================
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  echo " Updating system packages..."
  sudo apt update -y && sudo apt upgrade -y

  echo " Installing dependencies (MySQL, build tools, Redis, Git, Docker)..."
  sudo apt install -y mysql-client libmysqlclient-dev gcc make libssl-dev libbz2-dev libffi-dev zlib1g-dev \
      redis-server git docker.io fontconfig

  echo " Enabling & starting Redis..."
  sudo systemctl enable redis-server
  sudo systemctl start redis-server

  echo " Enabling & starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo " Installing Python 3.11.9 from source..."
  cd /opt/
  if [ ! -d "Python-3.11.9" ]; then
    sudo wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
    sudo tar xzf Python-3.11.9.tgz
  fi
  cd Python-3.11.9
  sudo ./configure --enable-optimizations
  sudo make altinstall

  echo " Verifying Python installation..."
  python3.11 --version
  python3.11 -m ensurepip --upgrade
  python3.11 -m pip install --upgrade pip

  echo " Ensuring Jenkins user exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  fi

  echo " Adding users to Docker group..."
  sudo usermod -aG docker "$DEVOPS_USER" || true
  sudo usermod -aG docker "$JENKINS_USER" || true

  echo " Restarting Docker..."
  sudo systemctl restart docker

# =====================================================================
# Amazon Linux / RHEL / CentOS Setup
# =====================================================================
elif [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
  echo " Updating system packages..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  else
    sudo yum update -y
  fi

  echo " Installing dependencies (MySQL client, build tools, Redis, Git, Docker)..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y mariadb git gcc make openssl-devel bzip2-devel libffi-devel zlib-devel redis docker
  else
    sudo yum install -y mariadb git gcc make openssl-devel bzip2-devel libffi-devel zlib-devel redis docker
  fi

  echo " Enabling & starting Redis..."
  sudo systemctl enable redis
  sudo systemctl start redis

  echo " Enabling & starting Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker

  echo " Installing Python 3.11.9 from source..."
  cd /opt/
  if [ ! -d "Python-3.11.9" ]; then
    sudo wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
    sudo tar xzf Python-3.11.9.tgz
  fi
  cd Python-3.11.9
  sudo ./configure --enable-optimizations
  sudo make altinstall

  echo "🔹 Verifying Python installation..."
  python3.11 --version
  python3.11 -m ensurepip --upgrade
  python3.11 -m pip install --upgrade pip

  echo "🔹 Ensuring Jenkins user exists..."
  if ! id "$JENKINS_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$JENKINS_USER"
    echo " Jenkins user created."
  fi

  echo "🔹 Adding users to Docker group..."
  sudo usermod -aG docker "$DEVOPS_USER" || true
  sudo usermod -aG docker "$JENKINS_USER" || true

  echo "🔹 Restarting Docker..."
  sudo systemctl restart docker

else
  echo " Unsupported OS: $OS"
  exit 1
fi

# =====================================================================
# Final Checks
# =====================================================================
echo "==============================================="
echo "  AIML Environment Setup Completed Successfully "
echo "==============================================="
echo " Installed Components:"
echo " - Python 3.11.9"
echo " - Redis (enabled & running)"
echo " - Docker (enabled & started)"
echo " - MySQL client libraries"
echo " - Git"
echo " Docker access granted to: $DEVOPS_USER, $JENKINS_USER"
echo "==============================================="
