#!/bin/bash -e

show_help() {
cat << EOF
Usage: ${0##*/} [-hv] [-a ARN] [-i GROUP,GROUP,...] [-l GROUP,GROUP,...] [-s GROUP]
Install import_users.sh and authorized_key_commands.

    -h              display this help and exit
    -v              verbose mode.

    -a arn          Assume a role before contacting AWS IAM to get users and keys.
                    This can be used if you define your users in one AWS account, while the EC2
                    instance you use this script runs in another.
    -i group,group  Which IAM groups have access to this instance
                    Comma seperated list of IAM groups. Leave empty for all available IAM users
    -l group,group  Give the users these local UNIX groups
                    Comma seperated list
    -s group        Specify an IAM group for users who should be given sudo privileges, or leave
                    empty to not change sudo access, or give it the value '##ALL##' to have all
                    users be given sudo rights.


EOF
}

IAM_GROUPS=""
SUDO_GROUP=""
LOCAL_GROUPS=""
ASSUME_ROLE=""

while getopts :hva:i:l:s: opt
do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        i)
            IAM_GROUPS="$OPTARG"
            ;;
        s)
            SUDO_GROUP="$OPTARG"
            ;;
        l)
            LOCAL_GROUPS="$OPTARG"
            ;;
        v)
            set -x
            ;;
        a)
            ASSUME_ROLE="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
    esac
done

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
if [ "${IAM_GROUPS}" != "" ]
then
    sed -i "s/IAM_AUTHORIZED_GROUPS=\"\"/IAM_AUTHORIZED_GROUPS=\"${IAM_GROUPS}\"/" /opt/import_users.sh
fi

# To control which users are given sudo privileges, uncomment the line below
# changing GROUPNAME to either the name of the IAM group for sudo users, or
# to ##ALL## to give all users sudo access. If you leave it blank, no users will
# be given sudo access.
if [ "${SUDO_GROUP}" != "" ]
then
    sed -i "s/SUDOERSGROUP=\"\"/SUDOERSGROUP=\"${SUDO_GROUP}\"/" /opt/import_users.sh
fi

# To control which local groups a user will get, uncomment the line belong
# changing GROUPNAMES to a comma seperated list of local UNIX groups.
# If you live it blank, this setting will be ignored
if [ "${LOCAL_GROUPS}" != "" ]
then
    sed -i "s/LOCAL_GROUPS=\"\"/LOCAL_GROUPS=\"${LOCAL_GROUPS}\"/" /opt/import_users.sh
fi

# If your IAM users are in another AWS account, put the AssumeRole ARN here.
# replace the word ASSUMEROLEARN with the full arn. eg 'arn:aws:iam::$accountid:role/$role'
# See docs/multiawsaccount.md on how to make this work
if [ "${ASSUME_ROLE}" != "" ]
then
    sed -i "s/ASSUMEROLE=\"\"/ASSUMEROLE=\"${ASSUME_ROLE}\"/" /opt/import_users.sh
    sed -i "s/ASSUMEROLE=\"\"/ASSUMEROLE=\"${ASSUME_ROLE}\"/" /opt/authorized_keys_command.sh
fi

sed -i 's:#AuthorizedKeysCommand none:AuthorizedKeysCommand /opt/authorized_keys_command.sh:g' /etc/ssh/sshd_config
sed -i 's:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config

echo "*/10 * * * * root /opt/import_users.sh" > /etc/cron.d/import_users
chmod 0644 /etc/cron.d/import_users

/opt/import_users.sh

service sshd restart
