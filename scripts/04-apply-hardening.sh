#!/usr/bin/env bash
set -euo pipefail

echo "🔒 Aplicando Hardening de Segurança..."

# 1. Aplicar Sysctl [cite: 739]
sudo cp infra/security/sysctl.conf /etc/sysctl.d/99-fricon-hardening.conf
sudo sysctl --system

# 2. Configurar Auditd 
# Copiar regras customizadas se existirem, caso contrário usa o default do init_server anterior
sudo cp infra/security/audit.rules /etc/audit/rules.d/fricon.rules 2>/dev/null || true
sudo systemctl restart auditd

# 3. SSH Hardening [cite: 431]
sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "✅ Hardening aplicado com sucesso!"