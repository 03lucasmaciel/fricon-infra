#!/usr/bin/env bash
# =======================================================
# Fricon - Verificador de Instalação
# Verifica o status de todos os componentes instalados
# =======================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       FRICON - Verificação de Instalação                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Função para verificar status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Função para verificar serviço
check_service() {
    if systemctl is-active --quiet "$1"; then
        echo -e "${GREEN}✓${NC} $1: Ativo"
    else
        echo -e "${RED}✗${NC} $1: Inativo"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}🛡️  SEGURANÇA${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# UFW
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(sudo ufw status | head -1 | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        echo -e "${GREEN}✓${NC} UFW Firewall: Ativo"
    else
        echo -e "${RED}✗${NC} UFW Firewall: Inativo"
    fi
else
    echo -e "${RED}✗${NC} UFW: Não instalado"
fi

# Fail2ban
check_service "fail2ban"

# Auditd
check_service "auditd"

# SSH
if [ -f /etc/ssh/sshd_config ]; then
    PERMIT_ROOT=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    PASS_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    
    if [ "$PERMIT_ROOT" = "no" ]; then
        echo -e "${GREEN}✓${NC} SSH: PermitRootLogin = no"
    else
        echo -e "${YELLOW}⚠${NC} SSH: PermitRootLogin = $PERMIT_ROOT"
    fi
    
    if [ "$PASS_AUTH" = "no" ]; then
        echo -e "${GREEN}✓${NC} SSH: PasswordAuthentication = no"
    else
        echo -e "${YELLOW}⚠${NC} SSH: PasswordAuthentication = $PASS_AUTH"
    fi
fi

# AIDE
if command -v aide >/dev/null 2>&1; then
    if [ -f /var/lib/aide/aide.db ]; then
        echo -e "${GREEN}✓${NC} AIDE: Instalado e inicializado"
    else
        echo -e "${YELLOW}⚠${NC} AIDE: Instalado mas não inicializado"
    fi
else
    echo -e "${RED}✗${NC} AIDE: Não instalado"
fi

# Unattended Upgrades
check_service "unattended-upgrades"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}🐳 DOCKER${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Docker
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}✓${NC} Docker: $DOCKER_VERSION"
    
    # Docker Compose
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short)
        echo -e "${GREEN}✓${NC} Docker Compose: $COMPOSE_VERSION"
    else
        echo -e "${RED}✗${NC} Docker Compose: Não disponível"
    fi
    
    # Docker service
    check_service "docker"
    
    # Containers em execução
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
    echo -e "${GREEN}ℹ${NC} Containers em execução: $RUNNING_CONTAINERS"
else
    echo -e "${RED}✗${NC} Docker: Não instalado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}🎨 TERMINAL & FERRAMENTAS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ZSH
if command -v zsh >/dev/null 2>&1; then
    ZSH_VERSION=$(zsh --version | awk '{print $2}')
    echo -e "${GREEN}✓${NC} ZSH: $ZSH_VERSION"
else
    echo -e "${RED}✗${NC} ZSH: Não instalado"
fi

# Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ] || [ -d "/home/ubuntu/.oh-my-zsh" ]; then
    echo -e "${GREEN}✓${NC} Oh My Zsh: Instalado"
else
    echo -e "${YELLOW}⚠${NC} Oh My Zsh: Não instalado"
fi

# Ferramentas modernas
TOOLS=("bat:batcat" "eza" "fd:fdfind" "rg:ripgrep" "ncdu" "duf" "tmux" "vim" "git")

for tool_pair in "${TOOLS[@]}"; do
    IFS=':' read -r tool display <<< "$tool_pair"
    display=${display:-$tool}
    
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $display"
    else
        echo -e "${YELLOW}⚠${NC} $display: Não encontrado"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📊 INFORMAÇÕES DO SISTEMA${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Timezone: $(timedatectl | grep "Time zone" | awk '{print $3}')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📋 LOGS DISPONÍVEIS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Logs do Fricon
if [ -d "/var/log/fricon" ]; then
    echo -e "${GREEN}✓${NC} Diretório de logs: /var/log/fricon/"
    echo ""
    echo "Logs de instalação disponíveis:"
    sudo ls -lht /var/log/fricon/*.log 2>/dev/null | head -5 || echo "  Nenhum log encontrado"
    echo ""
    if [ -f "/var/log/fricon/last_execution_summary.txt" ]; then
        echo -e "${GREEN}✓${NC} Sumário da última execução disponível:"
        echo "  sudo cat /var/log/fricon/last_execution_summary.txt"
    fi
else
    echo -e "${YELLOW}⚠${NC} Diretório de logs não encontrado"
fi

echo ""

# Logs de segurança
if [ -d "/var/log/security-reports" ]; then
    echo -e "${GREEN}✓${NC} Relatórios de segurança: /var/log/security-reports/"
    sudo ls -lht /var/log/security-reports/ 2>/dev/null | head -5 || echo "  Nenhum relatório encontrado"
else
    echo -e "${YELLOW}⚠${NC} Relatórios de segurança não encontrados"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}💡 COMANDOS ÚTEIS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Ver sumário da instalação:"
echo "  sudo cat /var/log/fricon/last_execution_summary.txt"
echo ""
echo "Ver log completo da instalação:"
echo "  sudo cat /var/log/fricon/init_server_*.log | less"
echo ""
echo "Ver relatório de segurança Lynis:"
echo "  sudo cat /var/log/security-reports/lynis-*.log | less"
echo ""
echo "Verificar regras de firewall:"
echo "  sudo ufw status verbose"
echo ""
echo "Ver aliases disponíveis:"
echo "  aliases-fricon"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
