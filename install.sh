#!/bin/bash

tmpdir=`mktemp -d`

cd $tmpdir

# yum install -y git # if necessary
# or download a tarball and decompress it instead
git clone https://github.com/widdix/aws-ec2-ssh.git

cd $tmpdir/aws-ec2-ssh

cp authorized_keys_command.sh /opt/authorized_keys_command.sh
cp import_users.sh /opt/import_users.sh

# To control which users are given access, uncomment the line below changing
# GROUPNAME to the name of the IAM group for users. If you leave it blank, all
# IAM users will be given access.
#sudo sed -i 's/UsersGroup="##ALL##"/UsersGroup="GROUPNAME"/' /opt/import_users.sh

# To control which users are given sudo privileges, uncomment the line below
# changing GROUPNAME to either the name of the IAM group for sudo users, or
# to ##ALL## to give all users sudo access. If you leave it blank, no users will
# be given sudo access.
#sudo sed -i 's/SudoersGroup=""/SudoersGroup="GROUPNAME"/' /opt/import_users.sh

sed -i 's:#AuthorizedKeysCommand none:AuthorizedKeysCommand /opt/authorized_keys_command.sh:g' /etc/ssh/sshd_config
sed -i 's:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config

echo "*/10 * * * * root /opt/import_users.sh" > /etc/cron.d/import_users
chmod 0644 /etc/cron.d/import_users

/opt/import_users.sh

service sshd restart
