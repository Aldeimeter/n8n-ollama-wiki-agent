#!/bin/bash

set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  echo "Docker already installed: $(docker --version)"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# Prerequisites
apt-get update
apt-get install -y curl ca-certificates

# Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

# apt repo
. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list


# install engine + compose plugin
apt-get update
apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# let the vagrant user run docker without sudo
usermod -aG docker vagrant

systemctl enable --now docker 

echo "docker installed: $(docker --version)"
