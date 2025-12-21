#!/bin/bash

USERNAME="adminuser"
DOMAIN="mydomain.com"
PASSWORD="Qwee123123@#"
EMAIL="admin@${DOMAIN}"

echo "========================================"
echo "Creating WHM Super User: $USERNAME"
echo "========================================"

if [ ! -f /scripts/wwwacct ]; then
    echo "ERROR: /scripts/wwwacct not found!"
    echo "Apakah Anda yakin ini server cPanel/WHM?"
    exit 1
fi

echo "[1/8] Creating cPanel account..."
/scripts/wwwacct $USERNAME $DOMAIN $PASSWORD $QUOTA $THEME $MAXFTP $MAXSQL $MAXPOP $MAXLST $MAXSUB $MAXPARK $MAXADDON $BWLIMIT $HASSHELL $OWNER $PLAN $RESELLER

sleep 2

if [ ! -f /var/cpanel/users/$USERNAME ]; then
    echo "ERROR: Failed to create account!"
    echo "Trying alternative method..."
    
    /usr/local/cpanel/bin/whmapi1 createacct \
        username=$USERNAME \
        domain=$DOMAIN \
        password=$PASSWORD \
        contactemail=$EMAIL \
        plan=default
    
    sleep 2
fi

if [ ! -f /var/cpanel/users/$USERNAME ]; then
    echo "ERROR: Account creation failed completely!"
    exit 1
fi

echo "✓ Account created successfully"

echo "[2/8] Converting to reseller..."
if [ -f /scripts/resellerstats ]; then
    /scripts/resellerstats $USERNAME
else
    /usr/local/cpanel/bin/whmapi1 setupreseller user=$USERNAME makeowner=0
fi

echo "[3/8] Setting full ACL..."
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
    acl-suspend-acct=1

echo "✓ ACL configured"

echo "[4/8] Setting unlimited resources..."
if [ -f /scripts/modifyacct ]; then
    /scripts/modifyacct $USERNAME QUOTA=unlimited BWLIMIT=unlimited
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
        MAXADDON=unlimited
fi

echo "✓ Resources set to unlimited"

echo "[5/8] Granting sudo access..."
if [ ! -d /etc/sudoers.d ]; then
    mkdir -p /etc/sudoers.d
fi

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME

if visudo -c -f /etc/sudoers.d/$USERNAME &>/dev/null; then
    echo "✓ Sudo access granted"
else
    echo "✗ Sudoers syntax error, removing..."
    rm -f /etc/sudoers.d/$USERNAME
fi

echo "[6/8] Adding deletion protection..."

if [ -f /var/cpanel/users/$USERNAME ]; then
    chattr +i /var/cpanel/users/$USERNAME
    echo "✓ Protected /var/cpanel/users/$USERNAME"
fi

if [ -d /home/$USERNAME ]; then
    chattr +i /home/$USERNAME
    echo "✓ Protected /home/$USERNAME"
fi

echo "[7/8] Creating deletion hook..."
cat > /usr/local/cpanel/scripts/pre_killacct << EOFHOOK
#!/bin/bash
PROTECTED_USERS="$USERNAME root"

for protected in \$PROTECTED_USERS; do
    if [ "\$1" = "\$protected" ]; then
        echo "================================================"
        echo "ERROR: Account '\$1' is PROTECTED!"
        echo "This account cannot be deleted."
        echo "================================================"
        exit 1
    fi
done

exit 0
EOFHOOK

chmod +x /usr/local/cpanel/scripts/pre_killacct
echo "✓ Deletion hook created"

echo "[8/8] Finalizing..."
chown -R $USERNAME:$USERNAME /home/$USERNAME 2>/dev/null
chmod 711 /home/$USERNAME 2>/dev/null

/scripts/updateuserdomains
/scripts/rebuildhttpdconf
/scripts/restartsrv_httpd

echo ""
echo "========================================"
echo "✓ INSTALLATION COMPLETE!"
echo "========================================"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo "Domain  : $DOMAIN"
echo ""
echo "cPanel URL: https://$(hostname -I | awk '{print $1}'):2083"
echo "WHM URL   : https://$(hostname -I | awk '{print $1}'):2087"
echo ""
echo "Test deletion protection:"
echo "/scripts/killacct $USERNAME"
echo "========================================"

echo ""
echo "Account Details:"
/usr/local/cpanel/bin/whmapi1 accountsummary user=$USERNAMEn
