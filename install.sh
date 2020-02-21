#!/bin/bash -e

show_help() {
cat << EOF
Usage: ${0##*/} [-hv] [--assume|-a <ARN>] [--import-groups <GROUP,...>] [--local-groups <GROUP,...>] [--sudo-groups <GROUP,...>]
  [--useradd-program <PROGRAM>] [--useradd-args <ARGUMENTS>] [--release|-r <RELEASE>]
Install import_users.sh and authorized_key_commands.

    -h, --help                      display this help and exit
    -v                              verbose mode.

    -a, --assume <arn>              Assume a role before contacting AWS IAM to get users and keys.
                                    This can be used if you define your users in one AWS account, while the EC2
                                    instance you use this script runs in another.
    --import-groups <group,group>   Import users from the IAM group(s) defined here (allow access to this instance).
                                    Comma seperated list of IAM groups. Define an empty string for all available IAM users.
    --import-groups-tag <tagKey>    Import users from the IAM group(s) defined here (allow access to this instance).
                                    Key of a tag found on EC2 instance with a value as defined for <import-groups>.
                                    One of import-groups or import-groups-tag must be defined.
    --local-groups <group,group>    Give the users these local UNIX groups
                                    Comma seperated list
    --sudo-groups <group,group>     Grant users in IAM group(s) defined here sudo privileges.
                                    Leave undefined or empty not grant sudo access, or provide the value '##ALL##'
                                    to grant all imported users sudo rights.
                                    Comma seperated list
    --sudo-groups-tag <tagKey>      Grant users in IAM group(s) defined here sudo privileges.
                                    Key of a tag found on EC2 instance with a value as defined for <sudo-groups>.
                                    Define either sudo-groups or sudo-groups-tag (not both).
    --useradd-program <program>     Specify your useradd program to use.
                                    Defaults to '/usr/sbin/useradd'
    --useradd-args <args string>    Specify arguments to use with useradd.
                                    Defaults to '--create-home --shell /bin/bash'
    -r, --release <release>         Specify a release of aws-ec2-ssh to download from GitHub. This argument is
                                    passed to \`git clone -b\` and so works with branches and tags.
                                    Defaults to 'master'


EOF
}

export SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
export AUTHORIZED_KEYS_COMMAND_FILE="/opt/authorized_keys_command.sh"
export IMPORT_USERS_SCRIPT_FILE="/opt/import_users.sh"
export MAIN_CONFIG_FILE="/etc/aws-ec2-ssh.conf"

IAM_GROUPS=""
IAM_GROUPS_TAG=""
SUDO_GROUPS=""
SUDO_GROUPS_TAG=""
LOCAL_GROUPS=""
ASSUME_ROLE=""
USERADD_PROGRAM=""
USERADD_ARGS=""
RELEASE="master"

if [ $# == 0 ] ; then
	echo "No input arguments provided. Please provide one or more input arguments."
	show_help
	exit 1
fi

#Process input arguments with GNU getopt to support long args
OPTS=`getopt -o hva:r: --l "assume:,import-groups:,import-groups-tag:,sudo-groups:,sudo-groups-tag:,local-groups:,useradd-program:,useradd-args:,release:,help" \
             -n 'install.sh' -- "$@"`

if [ $? != 0 ] ; then
	echo "Error while processing input arguments..." >&2
	exit 1
fi

eval set -- "$OPTS"

while [[ $# -gt 0 ]];
do
    case "$1" in
        -h | --help )
            show_help
            exit 0
            ;;
        -v )
            set -x
            shift ;;
        --import-groups )
            IAM_GROUPS="$2"
            shift 2;;
        --import-groups-tag )
            IAM_GROUPS_TAG="$2"
            shift 2;;
        --sudo-groups )
            SUDO_GROUPS="$2"
            shift 2;;
        --sudo-groups-tag )
            SUDO_GROUPS_TAG="$2"
            shift 2;;
        --local-groups )
            LOCAL_GROUPS="$2"
            shift 2;;
        -a | --assume )
            ASSUME_ROLE="$2"
            shift 2;;
        --useradd-program )
            USERADD_PROGRAM="$2"
            shift 2;;
        --useradd-args )
            USERADD_ARGS="$2"
            shift 2;;
        -r | --release )
            RELEASE="$2"
            shift 2;;
        \? )
            echo "Invalid option: $1" >&2
            show_help
            exit 1
            ;;
        -- )
            shift
            break;;
    esac
done

if [ ! -z "$IAM_GROUPS" ] && [ ! -z "$IAM_GROUPS_TAG" ] ; then
	echo "Define one of import-groups or import-groups-tag arguments, not both!"
	exit 1
fi

if [ ! -z "$SUDO_GROUPS" ] && [ ! -z "$SUDO_GROUPS_TAG" ] ; then
	echo "Define one of sudo-groups or sudo-groups-tag arguments, not both!"
	exit 1
fi

export IAM_GROUPS
export SUDO_GROUPS
export LOCAL_GROUPS
export ASSUME_ROLE
export USERADD_PROGRAM
export USERADD_ARGS

# check if AWS CLI exists
if ! [ -x "$(which aws)" ]; then
    echo "aws executable not found - exiting!"
    exit 1
fi

# check if git exists
if ! [ -x "$(which git)" ]; then
    echo "git executable not found - exiting!"
    exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# check if install script is part of a local git clone or downloaded as standalone
SOURCE_LOCATION=""
if [ -f $SCRIPTPATH/aws-ec2-ssh.conf ] && [ -d $SCRIPTPATH/.git/ ]; then
	SOURCE_LOCATION="local";
else
	SOURCE_LOCATION="github";
fi

echo "Source location: $SOURCE_LOCATION"

if [ $SOURCE_LOCATION == "github" ]; then
	tmpdir=$(mktemp -d)

	cd "$tmpdir"

	git clone -b "$RELEASE" https://github.com/widdix/aws-ec2-ssh.git
	
	cd "$tmpdir/aws-ec2-ssh"
else
	cd $SCRIPTPATH
fi

cp authorized_keys_command.sh $AUTHORIZED_KEYS_COMMAND_FILE
cp import_users.sh $IMPORT_USERS_SCRIPT_FILE
cat /dev/null > $MAIN_CONFIG_FILE

if [ "${IAM_GROUPS}" != "" ]
then
    echo "IAM_AUTHORIZED_GROUPS=\"${IAM_GROUPS}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${IAM_GROUPS_TAG}" != "" ]
then
    echo "IAM_AUTHORIZED_GROUPS_TAG=\"${IAM_GROUPS_TAG}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${SUDO_GROUPS}" != "" ]
then
    echo "SUDOERS_GROUPS=\"${SUDO_GROUPS}\"" >> $MAIN_CONFIG_FILE
fi

if [ "${SUDO_GROUPS_TAG}" != "" ]
then
    echo "SUDOERS_GROUPS_TAG=\"${SUDO_GROUPS_TAG}\"" >> $MAIN_CONFIG_FILE
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

./install_configure_selinux.sh

./install_configure_sshd.sh

cat > /etc/cron.d/import_users << EOF
SHELL=/bin/bash
PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin
MAILTO=root
HOME=/
@reboot      root $IMPORT_USERS_SCRIPT_FILE
*/10 * * * * root $IMPORT_USERS_SCRIPT_FILE
EOF
chmod 0644 /etc/cron.d/import_users

$IMPORT_USERS_SCRIPT_FILE

./install_restart_sshd.sh
