#!/bin/bash
set -ex

USERNAME=$1
CONFIG_REPO=$2
DOCKER_COMPOSE_VERSION=1.28.5

# apt has a tendency to fail during this process, this ensures that it retries
echo 'APT::Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries

# Perform installation of core dependencies

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  update

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ufw \
  fail2ban

curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
    -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  update

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  install \
  docker-ce \
  docker-ce-cli \
  containerd.io


# Docker compose install

curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
	-L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create administrative user

echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0400 /etc/sudoers.d/$USERNAME

groupadd $USERNAME
adduser \
  --shell /bin/bash \
  --disabled-password \
  --ingroup $USERNAME \
  --gecos "Administrative user" \
  $USERNAME
usermod -aG docker $USERNAME
mkdir -m700 /home/$USERNAME/.ssh
cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys

# Configure UFW

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https

# Update SSHD configuration
curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
	https://raw.githubusercontent.com/hashibuto/$CONFIG_REPO/master/config/sshd/ssh_config --output /etc/ssh/ssh_config

# Fail2Ban configuration for SSH
curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
	https://raw.githubusercontent.com/hashibuto/$CONFIG_REPO/master/config/fail2ban/defaults-debian.conf --output /etc/fail2ban/jail.d/defaults-debian.conf

curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
	https://raw.githubusercontent.com/hashibuto/$CONFIG_REPO/master/config/fail2ban/ufw-custom.conf --output /etc/fail2ban/action.d/ufw-custom.conf
curl \
	--connect-timeout 30 \
    --retry 5 \
    --retry-delay 15 \
    https://raw.githubusercontent.com/hashibuto/$CONFIG_REPO/master/config/fail2ban/jail.local --output /etc/fail2ban/jail.local

/etc/init.d/fail2ban restart

# Enable UFW
ufw --force enable
service ssh restart