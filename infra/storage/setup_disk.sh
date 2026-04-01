
#!/usr/bin/env bash
# Fricon - Setup de Storage Dedicado para Docker
set -euo pipefail

DISK="/dev/sdb" # Confirmar identificador no Proxmox
MOUNT_POINT="/var/lib/docker"

echo "Configurando storage dedicado em $MOUNT_POINT..."

# 1. Criar partição e formatar se não existir
if ! lsblk $DISK | grep -q "part"; then
    sudo parted -s $DISK mklabel gpt mkpart primary ext4 0% 100%
    sudo mkfs.ext4 "${DISK}1"
fi

# 2. Configurar FSTAB para persistência
UUID=$(sudo blkid -s UUID -o value "${DISK}1")
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    sudo mkdir -p $MOUNT_POINT
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab
    sudo mount -a
fi

echo "✅ Storage configurado com sucesso!"