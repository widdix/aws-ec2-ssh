#!/bin/bash -e

tmpdir=$(mktemp -d)

cd "$tmpdir"

git clone https://github.com/widdix/aws-ec2-ssh.git

cd "$tmpdir/aws-ec2-ssh"

cp authorized_keys_command.sh /opt/authorized_keys_command.sh
cp import_users.sh /opt/import_users.sh

# To control which users are imported/synced, uncomment the line below
# changing GROUPNAMES to a comma seperated list of IAM groups you want to sync.
# You can specify 1 or more groups, comma seperated, without spaces.
# If you leave it blank, all IAM users will be synced.
#echo 'IAM_AUTHORIZED_GROUPS="GROUPNAMES"' >> /etc/sysconfig/aws-ec2-ssh

# To control which users are given sudo privileges, uncomment the line below
# changing GROUPNAME to either the name of the IAM group for sudo users, or
# to ##ALL## to give all users sudo access. If you leave it blank, no users will
# be given sudo access.
#echo 'SUDOERSGROUP="GROUPNAME"' >> /etc/sysconfig/aws-ec2-ssh

# To control which local groups a user will get, uncomment the line belong
# changing GROUPNAMES to a comma seperated list of local UNIX groups.
# If you live it blank, this setting will be ignored
#echo 'LOCAL_GROUPS="GROUPNAMES"' >> /etc/sysconfig/aws-ec2-ssh

# If your IAM users are in another AWS account, put the AssumeRole ARN here.
# replace the word ASSUMEROLEARN with the full arn. eg 'arn:aws:iam::$accountid:role/$role'
# See docs/multiawsaccount.md on how to make this work
#echo 'ASSUMEROLE="ASSUMEROLEARN"' >> /etc/sysconfig/aws-ec2-ssh

sed -i 's:#AuthorizedKeysCommand none:AuthorizedKeysCommand /opt/authorized_keys_command.sh:g' /etc/ssh/sshd_config
sed -i 's:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config

echo "*/10 * * * * root /opt/import_users.sh" > /etc/cron.d/import_users
chmod 0644 /etc/cron.d/import_users

/opt/import_users.sh

service sshd restart
