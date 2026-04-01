#!/usr/bin/env bash
set -euo pipefail

echo "✨ Inicializando Baseline Debian 12..."

# Configurar Timezone e Locale [cite: 94]
sudo timedatectl set-timezone Europe/Lisbon

# Atualização e Ferramentas Essenciais [cite: 360, 361]
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git htop net-tools vim qemu-guest-agent ufw fail2ban auditd aide unattended-upgrades

# Ativar QEMU Guest Agent [cite: 371]
sudo systemctl enable --now qemu-guest-agent

# Firewall Básico [cite: 750, 752]
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 9443/tcp comment 'Portainer'
sudo ufw --force enable

echo "✅ Sistema base pronto!"