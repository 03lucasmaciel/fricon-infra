#!/usr/bin/env bash
# FRICON - Master Deploy Script

scripts=(
    "scripts/01-setup-storage.sh"
    "scripts/02-init-debian.sh"
    "scripts/03-install-docker.sh"
    "scripts/04-apply-hardening.sh"
)

for script in "${scripts[@]}"; do
    # Verificações para pular scripts se já configurados
    if [ "$script" == "scripts/01-setup-storage.sh" ]; then
        DISK="/dev/sdb"
        if lsblk $DISK | grep -q "part"; then
            echo "⏭️ Disco já particionado, a saltar setup de storage..."
            continue
        fi
    elif [ "$script" == "scripts/03-install-docker.sh" ]; then
        if [ -f /etc/docker/daemon.json ]; then
            echo "⏭️ Docker já configurado, a saltar..."
            continue
        fi
    fi

    echo "🚀 A executar: $script"
    bash "$script"
    echo "--------------------------------------"
done

# No final, corre o teu verificador
bash scripts/check_installation.sh