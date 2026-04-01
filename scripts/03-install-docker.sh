#!/usr/bin/env bash
# Fricon - Instalação Docker Engine (Debian Bookworm)
set -euo pipefail

# Detetar Codename do Debian
DEBIAN_CODENAME=$(lsb_release -cs)

echo "Instalando Docker para Debian $DEBIAN_CODENAME..."

# Remover versões antigas
sudo apt-get remove docker docker-engine docker.io containerd runc -y || true

# Configurar Repo Oficial
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $DEBIAN_CODENAME stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Aplicar o daemon.json da pasta de configs
sudo mkdir -p /etc/docker
sudo cp ../infra/docker/daemon.json /etc/docker/daemon.json

sudo systemctl restart docker
echo "✅ Docker instalado e configurado!"