#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Run This Script as R00T"
    exit 1
fi

OS="unknown"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    case "$ID" in
        ubuntu) OS="ubuntu" ;;
        debian) OS="debian" ;;
        centos|rhel) OS="centos" ;;
    esac
fi

if [ "$OS" = "unknown" ]; then
    echo "ERROR: Cant detect OS"
fi

RAND_STR=$(tr -dc 'a-z0-9' </dev/urandom | head -c5)
USERNAME="renvoza$RAND_STR"
PASSWORD="RenvozaPaSS!!$RAND_STR"

useradd -m -s /bin/bash "$USERNAME"

echo "$USERNAME:$PASSWORD" | chpasswd

if [[ "$OS" = "ubuntu" || "$OS" = "debian" ]]; then
    usermod -aG sudo "$USERNAME"
elif [[ "$OS" = "centos" ]]; then
    usermod -aG wheel "$USERNAME"
fi

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}


echo
echo "=============================================="
echo " USERS CREATED"
echo "----------------------------------------------"
echo " SSH PORT : $SSH_PORT"
echo " USERNAME : $USERNAME"
echo " PASSWORD : $PASSWORD"
echo "=============================================="
