#!/bin/bash -e

set -x

show_help() {
cat << EOF
Usage: ${0##*/} [-hv] [-a ARN] [-i GROUP,GROUP,...] [-l GROUP,GROUP,...] [-s GROUP] [-p PROGRAM] [-u "ARGUMENTS"]
Install import_users.sh and authorized_key_commands.

    -h                 display this help and exit
    -v                 verbose mode.

    -a arn             Assume a role before contacting AWS IAM to get users and keys.
                       This can be used if you define your users in one AWS account, while the EC2
                       instance you use this script runs in another.
    -i group,group     Which IAM groups have access to this instance
                       Comma seperated list of IAM groups. Leave empty for all available IAM users
    -l group,group     Give the users these local UNIX groups
                       Comma seperated list
    -s group,group     Specify IAM group(s) for users who should be given sudo privileges, or leave
                       empty to not change sudo access, or give it the value '##ALL##' to have all
                       users be given sudo rights.
                       Comma seperated list
    -p program         Specify your useradd program to use.
                       Defaults to '/usr/sbin/useradd'
    -u "useradd args"  Specify arguments to use with useradd.
                       Defaults to '--create-home --shell /bin/bash'
    -f s3_path         Get public keys from S3 instead of IAM


EOF
}

export SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
export AUTHORIZED_KEYS_COMMAND_FILE="/opt/authorized_keys_command.sh"
export IMPORT_USERS_SCRIPT_FILE="/opt/import_users.sh"
export MAIN_CONFIG_FILE="/etc/aws-ec2-ssh.conf"

IAM_GROUPS=""
SUDO_GROUPS=""
LOCAL_GROUPS=""
ASSUME_ROLE=""
USERADD_PROGRAM=""
USERADD_ARGS=""
S3_PATH=""

while getopts :hva:i:l:s:f: opt
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
            SUDO_GROUPS="$OPTARG"
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
        p)
            USERADD_PROGRAM="$OPTARG"
            ;;
        u)
            USERADD_ARGS="$OPTARG"
            ;;
        f)
            S3_PATH="$OPTARG"
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

export IAM_GROUPS
export SUDO_GROUPS
export LOCAL_GROUPS
export ASSUME_ROLE
export USERADD_PROGRAM
export USERADD_ARGS
export S3_PATH

# check if AWS CLI exists
if ! which aws; then
    echo "aws executable not found - exiting!"
    exit 1
fi

tmpdir=$(mktemp -d)

cd "$tmpdir"

git clone -b master https://github.com/brg-liuwei/aws-ec2-ssh.git

cd "$tmpdir/aws-ec2-ssh"

cp authorized_keys_command.sh $AUTHORIZED_KEYS_COMMAND_FILE
cp import_users.sh $IMPORT_USERS_SCRIPT_FILE

if [ "${IAM_GROUPS}" != "" ]
then
    echo "IAM_AUTHORIZED_GROUPS=\"${IAM_GROUPS}\"" > $MAIN_CONFIG_FILE
fi

if [ "${SUDO_GROUPS}" != "" ]
then
    echo "SUDOERS_GROUPS=\"${SUDO_GROUPS}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${LOCAL_GROUPS}" != "" ]
then
    echo "LOCAL_GROUPS=\"${LOCAL_GROUPS}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${ASSUME_ROLE}" != "" ]
then
    echo "ASSUMEROLE=\"${ASSUME_ROLE}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${USERADD_PROGRAM}" != "" ]
then
    echo "USERADD_PROGRAM=\"${USERADD_PROGRAM}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${USERADD_ARGS}" != "" ]
then
    echo "USERADD_ARGS=\"${USERADD_ARGS}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${S3_PATH}" != "" ]
then
    echo "S3_PATH=\"${S3_PATH}\"" >> $MAIN_CONFIG_FILE
fi

AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
echo "AWS_REGION=\"${AWS_REGION}\"" >> $MAIN_CONFIG_FILE

./install_configure_selinux.sh

./install_configure_sshd.sh

cat > /etc/cron.d/import_users << EOF
SHELL=/bin/bash
PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin
MAILTO=root
HOME=/
*/10 * * * * root $IMPORT_USERS_SCRIPT_FILE
EOF
chmod 0644 /etc/cron.d/import_users

$IMPORT_USERS_SCRIPT_FILE

./install_restart_sshd.sh
