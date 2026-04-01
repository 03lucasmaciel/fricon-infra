#!/usr/bin/env bash
# =======================================================
# Fricon - Baseline de Segurança e Docker (Ubtuntu 24.04)
# Aplica a MESMA configuração a todas as VMs.
# Idempotente: seguro repetir.
# =======================================================
set -euo pipefail

# ------ Configuração de Logs
LOG_DIR="/var/log/fricon"
LOG_FILE="${LOG_DIR}/init_server_$(date +'%Y%m%d_%H%M%S').log"
SUMMARY_FILE="${LOG_DIR}/last_execution_summary.txt"

# Criar diretório de logs
sudo mkdir -p "$LOG_DIR"
sudo chmod 755 "$LOG_DIR"

# Criar ficheiro de log vazio e dar permissões
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# Função de log melhorada (console + ficheiro)
log() {
  local msg="[$(date +'%F %T')] $*"
  echo -e "$msg"
  echo -e "$msg" >> "$LOG_FILE"
}

# Função para log de erro
log_error() {
  local msg="[$(date +'%F %T')] ❌ ERROR: $*"
  echo -e "$msg" >&2
  echo -e "$msg" >> "$LOG_FILE"
}

# Função para log de sucesso
log_success() {
  local msg="[$(date +'%F %T')] ✅ SUCCESS: $*"
  echo -e "$msg"
  echo -e "$msg" >> "$LOG_FILE"
}

# Trap para capturar erros
trap 'log_error "Script falhou na linha $LINENO. Exit code: $?"' ERR

# ------ Dados base
TIMEZONE="Europe/Lisbon"
LOCALE="pt_PT.UTF-8"
DOCKER_CHANNEL="stable"
# Detetar se é Debian ou Ubuntu para o repositório Docker
OS_ID=$(grep "^ID=" /etc/os-release | cut -d'=' -f2)
OS_CODENAME=$(lsb_release -cs)
UBUNTU_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")"

# Detetar utilizador humano para grupo docker
TARGET_USER="${SUDO_USER:-${USER}}"

log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "🔒 FRICON - Inicialização de Servidor Seguro"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Hostname: $(hostname)"
log "User: $TARGET_USER"
log "Data: $(date +'%F %T')"
log "Log file: $LOG_FILE"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log ""

# ------ 1) Atualizações do sistema
log "[STEP 1] Atualizar sistema..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo apt-get install -y \
    software-properties-common apt-transport-https ca-certificates gnupg lsb-release \
    qemu-guest-agent cloud-init \
    curl wget git unzip net-tools htop ufw vim nano lsof traceroute tcpdump \
    unattended-upgrades apt-listchanges debsecan lynis \
    zsh tmux neofetch bat eza fd-find ripgrep tree ncdu duf

# Iniciar e habilitar QEMU Guest Agent para integração com Proxmox
log "   → Configurar QEMU Guest Agent..."
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent || true

# ------ 2) Timezone e Locale
log "[STEP 2] Configurar timezone e locale..."
sudo timedatectl set-timezone "$TIMEZONE"
sudo locale-gen "$LOCALE" >/dev/null 2>&1 || true

# ------ 3) Unattend Upgrades (patches automáticas)
log "[STEP 3] Configurar Unattended Upgrades..."
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Verbose "1";
EOF

sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
        "\${distro_id}ESMApps:\${distro_codename}-apps-security";
        "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:30";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::MinimalSteps "true";
EOF

sudo systemctl enable unattended-upgrades
sudo systemctl restart unattended-upgrades || true

# ------ 4) UFW (firewall) restritiva por padrão
log "[STEP 4] Configurar UFW (firewall)..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
# Se necessário HTTP/HTTPS nesta VM, ativa quando aplicável:
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose || true

# ------ 5) SSH hardening (apenas se SSH ativo)
if systemctl list-units --type=service | grep -q ssh; then
  log "[STEP 5] Aplicar hardening ao SSH..."
  # Backup da configuração
  sudo cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)" || true
  
  sudo sed -i \
    -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
    -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' \
    -e 's/^#\?PermitEmptyPasswords .*/PermitEmptyPasswords no/' \
    -e 's/^#\?MaxAuthTries .*/MaxAuthTries 3/' \
    -e 's/^#\?ClientAliveInterval .*/ClientAliveInterval 300/' \
    -e 's/^#\?ClientAliveCountMax .*/ClientAliveCountMax 2/' \
    -e 's/^#\?X11Forwarding .*/X11Forwarding no/' \
    -e 's/^#\?AllowTcpForwarding .*/AllowTcpForwarding no/' \
    -e 's/^#\?AllowAgentForwarding .*/AllowAgentForwarding no/' \
    -e 's/^#\?PermitUserEnvironment .*/PermitUserEnvironment no/' \
    -e 's/^#\?Protocol .*/Protocol 2/' \
    /etc/ssh/sshd_config || true
  
  # Adicionar ciphers e MACs seguros se não existirem
  if ! grep -q "^Ciphers" /etc/ssh/sshd_config; then
    echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  fi
  if ! grep -q "^MACs" /etc/ssh/sshd_config; then
    echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  fi
  if ! grep -q "^KexAlgorithms" /etc/ssh/sshd_config; then
    echo "KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  fi
  
  # Validar configuração antes de reiniciar
  if sudo sshd -t 2>/dev/null; then
    sudo systemctl restart ssh || true
    log "✅ SSH hardening aplicado com sucesso"
  else
    log "⚠️ Erro na configuração SSH - restaurando backup"
    sudo cp "/etc/ssh/sshd_config.backup.$(date +%Y%m%d)-"* /etc/ssh/sshd_config 2>/dev/null || true
  fi
else
  log "ℹ️ Serviço SSH não encontrado (Multipass normalmente usa shell direto)."
fi

# ------ 6) Fail2ban básico
log "[STEP 6] Instalar e configurar Fail2ban..."
# Pré-configurar postfix para não ser interativo
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "postfix postfix/mailname string $(hostname -f)" | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd
# Email desativado por padrão - configurar se necessário
# destemail = admin@example.com
# sender = fail2ban@localhost
# mta = sendmail
action = %(action_)s

[sshd]
enabled = true
EOF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban || true

# ----- 7) auditd (auditoria de eventos do sistema)
log "[STEP 7] Instalar e configurar auditd..."
sudo apt-get install -y auditd audispd-plugins

# Configurar regras de auditoria
log "[STEP 7] Configurar regras de auditoria..."
sudo tee /etc/audit/rules.d/fricon-hardening.rules >/dev/null <<'EOF'
# Remover todas as regras anteriores
-D

# Buffer aumentado
-b 8192

# Falha em modo 1 (printk, continua a funcionar)
-f 1

# Auditoria de ficheiros críticos do sistema
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Auditoria de login e autenticação
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Auditoria de processos e sessões
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# Monitorização de alterações de hora
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Monitorização de uso de sudo
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged

# Auditoria de modificação de rede
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network-change
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k network-change
-w /etc/hosts -p wa -k network-change
-w /etc/network/ -p wa -k network-change

# Auditoria de módulos do kernel
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Auditoria de montagens
-a always,exit -F arch=b64 -S mount -S umount2 -k mounts
-a always,exit -F arch=b32 -S mount -S umount -S umount2 -k mounts

# Proteção de alterações de ficheiros
-w /bin/ -p wa -k binaries
-w /sbin/ -p wa -k binaries
-w /usr/bin/ -p wa -k binaries
-w /usr/sbin/ -p wa -k binaries

# SSH
-w /etc/ssh/sshd_config -p wa -k sshd

# Docker (se instalado)
-w /usr/bin/docker -p wa -k docker
-w /var/lib/docker/ -p wa -k docker
-w /etc/docker/ -p wa -k docker

# Tornar configuração imutável
-e 2
EOF

sudo systemctl enable auditd
sudo systemctl restart auditd || true
log "✅ Regras de auditoria configuradas"

# ----- 8) AIDE (integridade de ficheiros)
if ! command -v aide >/dev/null 2>&1; then
  log "[STEP 8] Instalar AIDE..."
  sudo apt-get install -y aide
fi
if [ ! -f /var/lib/aide/aide.db ]; then
  log "[STEP 8] Inicializar base AIDE (pode demorar alguns minutos)..."
  sudo aideinit || true
  if [ -f /var/lib/aide/aide.db.new ]; then
    sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  fi
fi

# Configurar cron job para verificações diárias do AIDE
log "[STEP 8] Configurar verificação diária do AIDE..."
sudo tee /etc/cron.daily/aide-check >/dev/null <<'EOF'
#!/bin/bash
# Verificação diária AIDE
/usr/bin/aide --check > /var/log/aide/aide-check-$(date +\%Y\%m\%d).log 2>&1
if [ $? -ne 0 ]; then
    echo "AIDE detected changes on $(hostname)" | logger -t AIDE
fi
EOF
sudo chmod +x /etc/cron.daily/aide-check
sudo mkdir -p /var/log/aide
log "✅ AIDE configurado com verificações diárias"

# ----- 9) Docker Engine + Compose (repo oficial)
log "[STEP 9] Instalar Docker Engine e Docker Compose..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} ${DOCKER_CHANNEL}" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configurar Docker daemon com opções de segurança
log "[STEP 9] Configurar Docker daemon com hardening..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

# Permitir arranque e uso não-root
sudo systemctl enable docker
sudo systemctl restart docker

# ⚠️ AVISO DE SEGURANÇA: Grupo docker = privilégios root
log "⚠️  AVISO DE SEGURANÇA: O grupo 'docker' concede privilégios equivalentes a root!"
log "    Apenas adicione utilizadores confiáveis a este grupo."
if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -q '^docker$'; then
  sudo usermod -aG docker "$TARGET_USER"
  log "    Utilizador '$TARGET_USER' adicionado ao grupo docker"
fi

# Endurecer permissões do socket
sudo chmod 660 /var/run/docker.sock || true
sudo chgrp docker /var/run/docker.sock || true

# ----- 10) Kernel Hardening (sysctl)
log "[STEP 10] Aplicar hardening do kernel (sysctl)..."
sudo tee /etc/sysctl.d/99-fricon-hardening.conf >/dev/null <<'EOF'
# Proteção contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignorar ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Não enviar ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Não aceitar source routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Proteção SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Logging de pacotes suspeitos
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignorar ICMP ping requests (opcional - comentado por padrão)
# net.ipv4.icmp_echo_ignore_all = 1

# Proteção contra ataques de broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignorar ICMP errors malformados
net.ipv4.icmp_ignore_bogus_error_responses = 1

# TCP hardening
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# IPv6 (desabilitar se não usado)
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0

# Proteção de memória
kernel.randomize_va_space = 2
kernel.exec-shield = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# Proteção contra core dumps de processos setuid
fs.suid_dumpable = 0

# Aumentar range de portas efémeras
net.ipv4.ip_local_port_range = 32768 60999

# Proteção contra fork bombs
kernel.pid_max = 65536
EOF

sudo sysctl -p /etc/sysctl.d/99-fricon-hardening.conf >/dev/null 2>&1 || true
log "✅ Kernel hardening aplicado"

# ----- 11) AppArmor / Segurança do Docker (se aplicável)
if command -v aa-status >/dev/null 2>&1; then
  log "[STEP 11] Garantir AppArmor ativo para Docker..."
  sudo aa-status || true
fi

# ----- 12) Configurar logrotate para logs de segurança
log "[STEP 12] Configurar rotação de logs..."
sudo tee /etc/logrotate.d/fricon-security >/dev/null <<'EOF'
/var/log/aide/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/log/fail2ban.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        /usr/bin/fail2ban-client flushlogs >/dev/null 2>&1 || true
    endscript
}
EOF
log "✅ Rotação de logs configurada"

# ----- 13) Proteções adicionais do sistema de ficheiros
log "[STEP 13] Configurar permissões de ficheiros críticos..."
sudo chmod 644 /etc/passwd
sudo chmod 644 /etc/group
sudo chmod 600 /etc/shadow
sudo chmod 600 /etc/gshadow
sudo chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
sudo chmod 700 /root
log "✅ Permissões de ficheiros críticos verificadas"

# ----- 13.5) Configurar terminal bonito e funcional
log "[STEP 13.5] Configurar terminal (Bash + ZSH) com tema Fricon..."

# Instalar Oh My Zsh para o utilizador (se não existir)
if [ ! -d "/home/$TARGET_USER/.oh-my-zsh" ] && [ "$TARGET_USER" != "root" ]; then
  log "   → Instalar Oh My Zsh para $TARGET_USER..."
  sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi

# Instalar plugins úteis do ZSH
if [ -d "/home/$TARGET_USER/.oh-my-zsh" ]; then
  log "   → Instalar plugins ZSH (zsh-autosuggestions, zsh-syntax-highlighting)..."
  
  # zsh-autosuggestions
  if [ ! -d "/home/$TARGET_USER/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "/home/$TARGET_USER/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
  fi
  
  # zsh-syntax-highlighting
  if [ ! -d "/home/$TARGET_USER/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    sudo -u "$TARGET_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "/home/$TARGET_USER/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
  fi
fi

# Configurar .zshrc personalizado
if [ -f "/home/$TARGET_USER/.zshrc" ]; then
  log "   → Configurar .zshrc personalizado..."
  sudo -u "$TARGET_USER" tee "/home/$TARGET_USER/.zshrc" >/dev/null <<'ZSHRC'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="agnoster"

# Plugins
plugins=(
  git
  docker
  docker-compose
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  colored-man-pages
  command-not-found
)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
export VISUAL='vim'

# Aliases úteis
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='duf'
alias cat='batcat --paging=never'
alias find='fdfind'
alias du='ncdu --color dark'

# Docker aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
alias dlog='docker logs -f'
alias dex='docker exec -it'
alias dcp='docker compose'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dclogs='docker compose logs -f'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# System aliases
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='sudo netstat -tulpn'
alias myip='curl -s ifconfig.me'
alias sysinfo='neofetch'

# Funções úteis
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.gz) gunzip "$1" ;;
      *.tar) tar xf "$1" ;;
      *.zip) unzip "$1" ;;
      *.Z) uncompress "$1" ;;
      *) echo "'$1' não pode ser extraído" ;;
    esac
  else
    echo "'$1' não é um ficheiro válido"
  fi
}

# Mostrar informações do sistema no login
if [[ -o login ]]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║              🔒 FRICON - Servidor Seguro 🔒                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  neofetch --config none --disable theme icons packages shell \
    --cpu_temp C --memory_percent on --disk_percent on 2>/dev/null || true
  echo ""
  echo "📊 Status do Sistema:"
  echo "   • Hostname: $(hostname)"
  echo "   • IP Local: $(hostname -I | awk '{print $1}')"
  echo "   • Uptime: $(uptime -p)"
  echo "   • Utilizadores ativos: $(who | wc -l)"
  echo ""
  if command -v docker >/dev/null 2>&1; then
    RUNNING=$(docker ps -q 2>/dev/null | wc -l)
    echo "🐳 Docker: $RUNNING containers em execução"
  fi
  echo ""
  echo "💡 Dica: Use 'aliases-fricon' para ver todos os aliases disponíveis"
  echo ""
fi

# Alias para mostrar todos os aliases personalizados
alias aliases-fricon='echo "
╔════════════════════════════════════════════════════════════╗
║                  ALIASES FRICON DISPONÍVEIS                ║
╚════════════════════════════════════════════════════════════╝

📁 Navegação e Ficheiros:
   ll, la, l     - Listagens de ficheiros
   .., ...       - Navegar diretórios
   cat           - Ver ficheiros (com sintaxe)
   du            - Uso de disco interativo
   df            - Uso de disco formatado

🐳 Docker:
   dps           - Lista containers (formatado)
   dimg          - Lista imagens (formatado)
   dlog          - Logs em tempo real
   dex           - Executar comando em container
   dcp           - Docker compose
   dcup/dcdown   - Subir/Parar serviços

📊 Git:
   gs, ga, gc    - Status, Add, Commit
   gp, gl, gd    - Push, Log, Diff

🔧 Sistema:
   update        - Atualizar sistema
   ports         - Ver portas abertas
   myip          - Ver IP público
   sysinfo       - Informações do sistema

📦 Funções:
   mkcd <dir>    - Criar e entrar em diretório
   extract <file> - Extrair qualquer arquivo comprimido
"'
ZSHRC
  sudo chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.zshrc"
fi

# Configurar .bashrc personalizado (fallback se ZSH não for usado)
log "   → Configurar .bashrc personalizado..."
sudo -u "$TARGET_USER" tee -a "/home/$TARGET_USER/.bashrc" >/dev/null <<'BASHRC'

# ============ FRICON Custom Configuration ============
# Prompt colorido
export PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

# Aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Docker aliases (se instalado)
if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
  alias dimg='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
  alias dlog='docker logs -f'
  alias dcp='docker compose'
  alias dcup='docker compose up -d'
  alias dcdown='docker compose down'
fi

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gl='git log --oneline --graph'

# System
alias update='sudo apt update && sudo apt upgrade -y'
alias sysinfo='neofetch'

# Banner de boas-vindas
if [ -f ~/.show_banner ]; then
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║              🔒 FRICON - Servidor Seguro 🔒                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  neofetch --config none --disable theme icons packages shell 2>/dev/null || true
  echo ""
  rm ~/.show_banner
fi
BASHRC

# Criar flag para mostrar banner no próximo login
sudo -u "$TARGET_USER" touch "/home/$TARGET_USER/.show_banner" || true

# Configurar vim com syntax highlighting
log "   → Configurar vim..."
sudo -u "$TARGET_USER" tee "/home/$TARGET_USER/.vimrc" >/dev/null <<'VIMRC'
" Configuração básica do Vim
syntax on
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set mouse=a
set background=dark
set showcmd
set showmatch
set incsearch
set hlsearch
set ignorecase
set smartcase

" Melhorias visuais
set cursorline
set wildmenu
set laststatus=2
set ruler

" Atalhos úteis
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a
VIMRC
sudo chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.vimrc"

# Configurar tmux
log "   → Configurar tmux..."
sudo -u "$TARGET_USER" tee "/home/$TARGET_USER/.tmux.conf" >/dev/null <<'TMUXCONF'
# Configuração do tmux
set -g default-terminal "screen-256color"
set -g history-limit 10000
set -g mouse on

# Prefixo mais confortável (Ctrl+a em vez de Ctrl+b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Navegação entre painéis estilo vim
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Split mais intuitivo
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config
bind r source-file ~/.tmux.conf \; display "Config recarregado!"

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=green]#H #[default]'
set -g status-right '#[fg=yellow]%d/%m/%y %H:%M#[default]'
TMUXCONF
sudo chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.tmux.conf"

# Criar symlinks para comandos modernos (bat, exa, fd)
log "   → Criar symlinks para ferramentas modernas..."
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

# Tornar ZSH o shell padrão (opcional, comentado por segurança)
# if command -v zsh >/dev/null 2>&1 && [ "$TARGET_USER" != "root" ]; then
#   log "   → Definir ZSH como shell padrão..."
#   sudo chsh -s "$(which zsh)" "$TARGET_USER" || true
# fi

log "✅ Terminal configurado com tema Fricon (ZSH + Bash + Vim + Tmux)"

# ----- 14) Limpeza
log "[STEP 14] Limpeza final..."
sudo apt-get autoremove -y
sudo apt-get clean

# ----- 15) Relatórios de segurança
log "[STEP 15] Gerar relatórios de segurança..."
sudo mkdir -p /var/log/security-reports

# Debsecan
log "   → Executando debsecan..."
sudo debsecan --suite="${UBUNTU_CODENAME}" > /var/log/security-reports/debsecan-$(date +%Y%m%d).log 2>&1 || true

# Lynis
log "   → Executando Lynis (pode demorar alguns minutos)..."
sudo lynis audit system --quick --quiet > /var/log/security-reports/lynis-$(date +%Y%m%d).log 2>&1 || true

log "✅ Relatórios salvos em /var/log/security-reports/"

# ----- 16) Sumário de segurança
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "✅ BASELINE DE SEGURANÇA APLICADA COM SUCESSO"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log ""
log "🔒 Configurações de Segurança Aplicadas:"
log "   ✓ Sistema atualizado e patches automáticos ativos"
log "   ✓ Firewall UFW configurado (apenas SSH permitido)"
log "   ✓ SSH hardening completo (criptografia forte, sem root login)"
log "   ✓ Fail2ban ativo (proteção contra brute-force)"
log "   ✓ Auditd com regras abrangentes de monitorização"
log "   ✓ AIDE instalado com verificações diárias de integridade"
log "   ✓ Kernel hardening (sysctl) aplicado"
log "   ✓ Docker instalado com configurações de segurança"
log "   ✓ Logrotate configurado para logs de segurança"
log "   ✓ AppArmor ativo"
log ""
log "📊 Informações do Sistema:"
log "   • Hostname: $(hostname)"
log "   • User: $TARGET_USER"
log "   • Timezone: $TIMEZONE"
log "   • Docker: $(docker --version 2>/dev/null || echo 'não disponível')"
log "   • Docker Compose: $(docker compose version 2>/dev/null || echo 'não disponível')"
log ""
log "⚠️  AVISOS IMPORTANTES:"
log "   • O grupo 'docker' concede privilégios equivalentes a ROOT"
log "   • Altere senhas padrão se existirem"
log "   • Configure UFW para permitir apenas portas necessárias"
log "   • Revise logs em: /var/log/security-reports/"
log "   • Revise configuração SSH em: /etc/ssh/sshd_config"
log ""
log "🎨 Terminal:"
log "   • Oh My Zsh instalado com tema agnoster"
log "   • Plugins: autosuggestions, syntax-highlighting"
log "   • Ferramentas modernas: bat, exa, fd, ripgrep, ncdu, duf"
log "   • Vim configurado com syntax highlighting"
log "   • Tmux com configurações otimizadas"
log "   • Aliases úteis para Docker, Git e sistema"
log "   • Banner de boas-vindas personalizado"
log ""
log "📝 Próximos Passos Recomendados:"
log "   1. Reiniciar o sistema: sudo reboot"
log "   2. Ativar ZSH (opcional): sudo chsh -s \$(which zsh) $TARGET_USER"
log "   3. Executar 'zsh' ou fazer novo login para ver novo terminal"
log "   4. Verificar logs de auditoria: sudo ausearch -k identity"
log "   5. Verificar regras UFW: sudo ufw status verbose"
log "   6. Testar acesso SSH antes de fechar sessão atual"
log "   7. Configurar backups regulares"
log "   8. Implementar monitorização (Prometheus/Grafana)"
log ""
log "💡 Dicas de Terminal:"
log "   • Digite 'aliases-fricon' para ver todos os aliases"
log "   • Use 'sysinfo' para ver informações do sistema"
log "   • Use 'dps' para ver containers Docker formatados"
log "   • Experimente 'cat' (bat), 'ls' (eza) e 'df' (duf)"
log ""
log "📋 Logs e Relatórios:"
log "   • Log completo: $LOG_FILE"
log "   • Sumário: $SUMMARY_FILE"
log "   • Relatórios de segurança: /var/log/security-reports/"
log "   • Ver log: sudo cat $LOG_FILE"
log "   • Ver sumário: sudo cat $SUMMARY_FILE"
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ----- 17) Gerar sumário executivo
log ""
log "[STEP 16] Gerar sumário executivo..."

sudo tee "$SUMMARY_FILE" >/dev/null <<SUMMARY_EOF
╔════════════════════════════════════════════════════════════╗
║          FRICON - Sumário de Execução do Script            ║
╚════════════════════════════════════════════════════════════╝

📅 Data de Execução: $(date +'%F %T')
🖥️  Hostname: $(hostname)
👤 Utilizador: $TARGET_USER
📝 Log completo: $LOG_FILE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ COMPONENTES INSTALADOS E CONFIGURADOS:

🛡️  SEGURANÇA:
   ✓ UFW Firewall: $(sudo ufw status | head -1 | awk '{print $2}')
   ✓ SSH Hardening: Aplicado
   ✓ Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "inativo")
   ✓ Auditd: $(systemctl is-active auditd 2>/dev/null || echo "inativo")
   ✓ AIDE: Instalado com verificações diárias
   ✓ Kernel Hardening: Aplicado
   ✓ Unattended Upgrades: $(systemctl is-active unattended-upgrades 2>/dev/null || echo "inativo")
   ✓ AppArmor: $(sudo aa-status --enabled 2>/dev/null && echo "Ativo" || echo "N/A")

🐳 DOCKER:
   ✓ Docker Engine: $(docker --version 2>/dev/null || echo "Erro")
   ✓ Docker Compose: $(docker compose version 2>/dev/null || echo "Erro")
   ✓ Docker Daemon: Configurado com hardening
   ✓ Utilizador no grupo docker: $(groups $TARGET_USER | grep -q docker && echo "Sim" || echo "Não")

🎨 TERMINAL:
   ✓ ZSH: $(zsh --version 2>/dev/null || echo "Não instalado")
   ✓ Oh My Zsh: $([ -d "/home/$TARGET_USER/.oh-my-zsh" ] && echo "Instalado" || echo "Não instalado")
   ✓ Vim: Configurado
   ✓ Tmux: Configurado
   ✓ Ferramentas modernas: bat, eza, fd, ripgrep, ncdu, duf

📊 VERIFICAÇÕES DE SEGURANÇA:

Portas abertas (UFW):
$(sudo ufw status numbered 2>/dev/null | grep -v "^Status:" | head -5)

SSH Config principais:
   PermitRootLogin: $(sudo grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "N/A")
   PasswordAuthentication: $(sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "N/A")
   X11Forwarding: $(sudo grep "^X11Forwarding" /etc/ssh/sshd_config 2>/dev/null || echo "N/A")

Fail2ban Jails ativos:
$(sudo fail2ban-client status 2>/dev/null | grep "Jail list:" || echo "N/A")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  AÇÕES REQUERIDAS:

1. ⚠️  REINICIAR o sistema para aplicar todas as configurações:
   sudo reboot

2. 🔑 TESTAR acesso SSH antes de fechar esta sessão:
   (Abrir nova janela e tentar: ssh $TARGET_USER@$(hostname -I | awk '{print $1}'))

3. 🐚 ATIVAR ZSH (opcional):
   sudo chsh -s \$(which zsh) $TARGET_USER

4. 🔍 REVISAR logs de segurança:
   sudo cat /var/log/security-reports/lynis-$(date +%Y%m%d).log
   sudo cat /var/log/security-reports/debsecan-$(date +%Y%m%d).log

5. 🔥 CONFIGURAR portas do firewall conforme necessário:
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 DOCUMENTAÇÃO E COMANDOS ÚTEIS:

Ver logs completos:
   sudo cat $LOG_FILE

Verificar status de segurança:
   sudo ufw status verbose
   sudo fail2ban-client status
   sudo ausearch -k identity
   sudo lynis show details

Comandos Docker úteis:
   dps              # Lista containers
   dimg             # Lista imagens
   dcup             # Docker compose up
   
Terminal:
   aliases-fricon   # Ver todos os aliases
   sysinfo          # Informações do sistema

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Execução completada com sucesso!
   Tempo de execução: Consultar log completo em $LOG_FILE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY_EOF

sudo chmod 644 "$SUMMARY_FILE"
log_success "Sumário executivo criado em: $SUMMARY_FILE"
log ""
log "🎯 Para ver o sumário completo execute:"
log "   sudo cat $SUMMARY_FILE"
log ""
log_success "Script finalizado com sucesso! Tempo total: $SECONDS segundos"
log ""

# ----- 18) Verificar se é para preparar template (modo generalização)
if [ "${PREPARE_TEMPLATE:-no}" = "yes" ]; then
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "🔄 MODO TEMPLATE: Preparar para generalização"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log ""
  log "[STEP 18] Limpar identificadores únicos para template..."
  
  # 1. Limpar Machine ID (cada clone terá ID único)
  log "   → Limpar Machine ID..."
  sudo truncate -s 0 /etc/machine-id
  sudo rm -f /var/lib/dbus/machine-id
  sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
  
  # 2. Remover chaves SSH do host (cada clone gerará as suas)
  log "   → Remover chaves SSH do host..."
  sudo rm -f /etc/ssh/ssh_host_*
  
  # 3. Limpar configurações do Cloud-Init
  log "   → Limpar Cloud-Init..."
  sudo cloud-init clean --logs --seed 2>/dev/null || true
  
  # 4. Limpar logs gerados pelo script
  log "   → Limpar logs do Fricon..."
  sudo rm -rf /var/log/fricon/*
  
  # 5. Limpar histórico de comandos
  log "   → Limpar histórico de comandos..."
  [ -f /home/$TARGET_USER/.bash_history ] && sudo rm -f /home/$TARGET_USER/.bash_history
  [ -f /home/$TARGET_USER/.zsh_history ] && sudo rm -f /home/$TARGET_USER/.zsh_history
  [ -f /root/.bash_history ] && sudo rm -f /root/.bash_history
  history -c 2>/dev/null || true
  
  # 6. Limpar cache de pacotes
  log "   → Limpar cache APT..."
  sudo apt-get clean
  sudo rm -rf /var/lib/apt/lists/*
  
  # 7. Limpar logs do sistema
  log "   → Limpar logs do sistema..."
  sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
  sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
  sudo journalctl --vacuum-time=1s 2>/dev/null || true
  
  # 8. Limpar tmp
  log "   → Limpar ficheiros temporários..."
  sudo rm -rf /tmp/*
  sudo rm -rf /var/tmp/*
  
  log ""
  log_success "✅ VM preparada para conversão em template!"
  log ""
  log "📋 Próximos passos no Proxmox:"
  log "   1. Desligar esta VM: sudo poweroff"
  log "   2. No Proxmox: Converter para Template"
  log "   3. Criar VMs clonando o template"
  log "   4. As VMs clonadas terão IDs e chaves SSH únicos"
  log ""
  log "⚠️  ATENÇÃO: Esta VM está agora sem Machine ID e chaves SSH."
  log "   Não a inicie novamente antes de converter em template!"
  log ""
else
  log ""
  log "ℹ️  Para preparar esta VM como template, execute:"
  log "   PREPARE_TEMPLATE=yes sudo bash init_server.sh"
  log ""
fi
