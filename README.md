# 🔒 Fricon Infrastructure

> Baseline de segurança e configuração padronizada para servidores Ubuntu 24.04

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![Security](https://img.shields.io/badge/Security-Hardened-green)](https://www.cisecurity.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 Visão Geral

Este repositório contém scripts e configurações para inicializar e padronizar servidores Ubuntu 24.04 com foco em **segurança**, **consistência** e **produtividade**. O script `init_server.sh` aplica automaticamente um conjunto abrangente de configurações de segurança e ferramentas que tornam todos os servidores idênticos e seguros.

## ✨ Funcionalidades

### 🛡️ Segurança (CIS Benchmark Compliant)

- ✅ **Firewall UFW** configurado (deny incoming, allow outgoing)
- ✅ **SSH Hardening** completo
  - Sem login root
  - Apenas autenticação por chave
  - Criptografia forte (ChaCha20, AES-GCM)
  - Desativação de X11 e TCP forwarding
- ✅ **Fail2ban** para proteção contra brute-force
- ✅ **Auditd** com regras abrangentes de monitorização
- ✅ **AIDE** (Advanced Intrusion Detection) com verificações diárias
- ✅ **Kernel Hardening** via sysctl
- ✅ **Unattended Upgrades** para patches automáticos
- ✅ **AppArmor** habilitado
- ✅ **Permissões de ficheiros** críticos validadas

### 🐳 Docker

- Docker Engine (versão oficial mais recente)
- Docker Compose Plugin
- Configuração segura do daemon
- Logs com rotação automática
- AppArmor profiles ativos

### 🎨 Terminal & Produtividade

- **Oh My Zsh** com tema Agnoster
- **Plugins ZSH**:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
  - git, docker, colored-man-pages
- **Ferramentas modernas**:
  - `bat` (cat melhorado)
  - `eza` (ls moderno)
  - `fd` (find rápido)
  - `ripgrep` (grep turbinado)
  - `ncdu` (analisador de disco)
  - `duf` (df bonito)
  - `neofetch` (system info)
- **Vim** configurado com syntax highlighting
- **Tmux** com atalhos otimizados
- **Aliases úteis** para Docker, Git e sistema
- **Banner personalizado** no login

### 📊 Monitorização & Auditoria

- Logs centralizados com logrotate
- Relatórios de segurança (Lynis, Debsecan)
- Auditoria de eventos críticos do sistema
- Verificação de integridade de ficheiros

## 🚀 Instalação Rápida

### Pré-requisitos

- Ubuntu 24.04 LTS (limpo ou existente)
- Acesso SSH ou console
- Utilizador com privilégios sudo

### Execução

```bash
# 1. Clonar o repositório
git clone https://github.com/lucasmaciel03/fricon-infra.git
cd fricon-infra

# 2. Tornar o script executável
chmod +x init_server.sh

# 3. Executar o script
sudo bash init_server.sh
```

> ⏱️ **Tempo de execução**: 5-15 minutos (dependendo da velocidade da rede e CPU)

### Após a Execução

```bash
# 1. Reiniciar o sistema (recomendado)
sudo reboot

# 2. Fazer novo login e ativar ZSH
zsh

# 3. (Opcional) Tornar ZSH o shell padrão
sudo chsh -s $(which zsh) $USER
```

## 📦 O Que é Instalado e Configurado

### Pacotes de Segurança

- `ufw` - Firewall
- `fail2ban` - Proteção contra brute-force
- `auditd` - Auditoria do sistema
- `aide` - Detecção de intrusão
- `lynis` - Scanner de segurança
- `debsecan` - Scanner de vulnerabilidades
- `unattended-upgrades` - Updates automáticos

### Ferramentas de Desenvolvimento

- `git` - Controlo de versão
- `docker` + `docker-compose` - Containerização
- `curl`, `wget` - Downloads
- `vim`, `nano` - Editores de texto

### Ferramentas de Sistema

- `htop` - Monitor de processos
- `tmux` - Multiplexador de terminal
- `neofetch` - Informações do sistema
- `net-tools`, `lsof`, `traceroute`, `tcpdump` - Network tools

### Ferramentas Modernas

- `bat` - Visualizador de ficheiros com syntax
- `eza` - Listagem de ficheiros melhorada
- `fd` - Busca de ficheiros rápida
- `ripgrep` - Busca em texto ultrarrápida
- `ncdu` - Analisador de disco interativo
- `duf` - Informação de disco formatada

## 🔧 Configurações Aplicadas

### SSH (`/etc/ssh/sshd_config`)

```bash
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
```

### Firewall (UFW)

```bash
Default: DENY incoming, ALLOW outgoing
Allowed: OpenSSH (22/tcp)
```

### Kernel (sysctl)

- Proteção contra IP spoofing
- Proteção SYN flood
- ASLR (Address Space Layout Randomization)
- Desativação de ICMP redirects
- TCP hardening

### Docker Daemon (`/etc/docker/daemon.json`)

```json
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "no-new-privileges": true
}
```

## 🎯 Aliases Úteis

### Docker

```bash
dps          # Lista containers formatada
dimg         # Lista imagens formatadas
dlog         # Logs em tempo real
dex          # Executar comando em container
dcup         # Docker compose up -d
dcdown       # Docker compose down
dclogs       # Docker compose logs -f
```

### Git

```bash
gs           # git status
ga           # git add
gc           # git commit
gp           # git push
gl           # git log (bonito)
```

### Sistema

```bash
update       # Atualizar sistema completo
ports        # Ver portas abertas
myip         # Ver IP público
sysinfo      # Informações do sistema (neofetch)
aliases-fricon  # Ver todos os aliases
```

### Funções

```bash
mkcd <dir>     # Criar e entrar em diretório
extract <file> # Extrair qualquer arquivo comprimido
```

## 📁 Estrutura de Ficheiros Importantes

```
/etc/
├── ssh/sshd_config                      # Configuração SSH hardened
├── docker/daemon.json                   # Configuração Docker segura
├── ufw/                                 # Regras de firewall
├── audit/rules.d/fricon-hardening.rules # Regras de auditoria
├── fail2ban/jail.local                  # Configuração Fail2ban
└── sysctl.d/99-fricon-hardening.conf   # Kernel hardening

/var/log/
├── security-reports/                    # Relatórios Lynis e Debsecan
├── aide/                                # Logs AIDE
└── audit/                               # Logs de auditoria

/home/<user>/
├── .zshrc                               # Configuração ZSH
├── .bashrc                              # Configuração Bash
├── .vimrc                               # Configuração Vim
└── .tmux.conf                           # Configuração Tmux
```

## 🔍 Verificações Pós-Instalação

### Verificar Segurança

```bash
# Status do firewall
sudo ufw status verbose

# Status do Fail2ban
sudo fail2ban-client status

# Últimas auditorias
sudo ausearch -k identity

# Relatório de segurança
sudo lynis show details

# Verificar integridade de ficheiros
sudo aide --check
```

### Verificar Docker

```bash
# Versão do Docker
docker --version
docker compose version

# Containers em execução
docker ps

# Informações do sistema Docker
docker info
```

### Verificar Terminal

```bash
# Versão do ZSH
zsh --version

# Plugins ativos
echo $plugins

# Aliases disponíveis
aliases-fricon
```

## ⚠️ Avisos de Segurança

### Grupo Docker

> **⚠️ CRÍTICO**: O grupo `docker` concede privilégios equivalentes a **root**. Qualquer utilizador neste grupo pode escalar privilégios. Adicione apenas utilizadores confiáveis.

### Firewall

> Configure portas adicionais conforme necessário:

```bash
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 3000/tcp  # Aplicação personalizada
```

### SSH

> **Antes de fechar a sessão atual**, teste o acesso SSH em outra janela para garantir que não ficou bloqueado.

## 🔄 Manutenção Regular

### Atualizações

```bash
# Manual
sudo apt update && sudo apt upgrade -y

# Automático (já configurado)
# Unattended upgrades executam diariamente às 03:30
```

### Verificações de Segurança

```bash
# Executar Lynis mensalmente
sudo lynis audit system

# Verificar AIDE
sudo aide --check

# Revisar logs de auditoria
sudo ausearch -ts recent
```

## 📊 Compatibilidade

| Sistema Operacional | Versão | Status            |
| ------------------- | ------ | ----------------- |
| Ubuntu              | 24.04  | ✅ Testado        |
| Ubuntu              | 22.04  | ⚠️ Pode funcionar |
| Ubuntu              | 20.04  | ⚠️ Pode funcionar |
| Debian              | 12     | ⚠️ Não testado    |

## 🤝 Contribuir

Contribuições são bem-vindas! Por favor:

1. Fork o repositório
2. Crie um branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para o branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## 📝 Changelog

### v1.0.0 (2025-11-06)

- ✨ Script inicial de baseline de segurança
- ✨ SSH hardening completo
- ✨ Configuração Docker segura
- ✨ Auditd com regras abrangentes
- ✨ AIDE com verificações diárias
- ✨ Kernel hardening (sysctl)
- ✨ Terminal personalizado (ZSH + Oh My Zsh)
- ✨ Ferramentas modernas (bat, eza, fd, etc.)
- ✨ Aliases e funções úteis

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

---
