#!/bin/bash

#cp authorized_keys_command.sh /opt/authorized_keys_command.sh
cat > /opt/authorized_keys_command.sh  <<'EOF'
#!/bin/bash -e

if [ -z "$1" ]; then
  exit 1
fi

aws iam list-ssh-public-keys --user-name "$1" --query "SSHPublicKeys[?Status == 'Active'].[SSHPublicKeyId]" --output text | while read KeyId; do
  aws iam get-ssh-public-key --user-name "$1" --ssh-public-key-id "$KeyId" --encoding SSH --query "SSHPublicKey.SSHPublicKeyBody" --output text
done
EOF
chmod +x /opt/authorized_keys_command.sh

#cp import_users.sh /opt/import_users.sh
cat > /opt/import_users.sh <<'EOF'
#!/bin/bash

aws iam list-users --query "Users[].[UserName]" --output text | while read User; do
  if id -u "$User" >/dev/null 2>&1; then
    echo "$User exists"
  else
    /usr/sbin/adduser "$User"
    echo "$User ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$User"
  fi
done
EOF

chmod +x /opt/import_users.sh

sed -i 's:#AuthorizedKeysCommand none:AuthorizedKeysCommand /opt/authorized_keys_command.sh:g' /etc/ssh/sshd_config
sed -i 's:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config

echo "*/10 * * * * root /opt/import_users.sh" > /etc/cron.d/import_users
chmod 0644 /etc/cron.d/import_users

/opt/import_users.sh

service sshd restart