#!/bin/bash -e

show_help() {
cat << EOF
Usage: ${0##*/} [-hv] [--assume|-a <ARN>] [--import-groups <GROUP,...>] [--local-groups <GROUP,...>] [--sudo-groups <GROUP,...>]
  [--useradd-program <PROGRAM>] [--useradd-args <ARGUMENTS>] [--release|-r <RELEASE>]
Install import_users.sh and authorized_key_commands.

    -h, --help                          display this help and exit
    -v                                  verbose mode.

    -a, --assume <arn>                  Assume a role before contacting AWS IAM to get users and keys.
                                        This can be used if you define your users in one AWS account, while the EC2
                                        instance you use this script runs in another.
    --import-groups <group,group>       Import users from the IAM group(s) defined here (allow access to this instance).
                                        Comma seperated list of IAM groups. Define an empty string for all available IAM users.
    --import-groups-tag <tagKey>        Import users from the IAM group(s) defined here (allow access to this instance).
                                        Key of a tag found on EC2 instance with a value as defined for <import-groups>.
                                        One of import-groups or import-groups-tag must be defined.
    --local-groups <group,group>        Add all imported users to these local UNIX groups
                                        Comma seperated list
    --local-group-map <json-groupmap>   Add specific iam-groups to specific local UNIX groups.
                                        JSON-object
                                        For every UNIX group defined (key), add all users from array of iam groups (value).
    --local-group-map-tag <tagKey>      Give specific user groups specific local UNIX groups.
                                        Key of a tag found on EC2 instance with a value as defined for <local-group-map>.
    --sudo-groups <group,group>         Grant users in IAM group(s) defined here sudo privileges.
                                        Leave undefined or empty not grant sudo access, or provide the value '##ALL##'
                                        to grant all imported users sudo rights.
                                        Comma seperated list
    --sudo-groups-tag <tagKey>          Grant users in IAM group(s) defined here sudo privileges.
                                        Key of a tag found on EC2 instance with a value as defined for <sudo-groups>.
                                        Define either sudo-groups or sudo-groups-tag (not both).
    --useradd-program <program>         Specify your useradd program to use.
                                        Defaults to '/usr/sbin/useradd'
    --useradd-args <args string>        Specify arguments to use with useradd.
                                        Defaults to '--create-home --shell /bin/bash'
    --local-marker-group <groupname>    Local group will be searched and transfered to state file if found. (legacy support)
                                        Define empty string to disable this check.
                                        Defaults to 'iam-synced-users'
    --clean-state                       When defined, the state file will be wiped clean before running installation.
    -r, --release <release>             Specify a release of aws-ec2-ssh to download from GitHub. This argument is
                                        passed to \`git clone -b\` and so works with branches and tags.
                                        Defaults to 'master'


EOF
}

export SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
export AUTHORIZED_KEYS_COMMAND_FILE="/opt/authorized_keys_command.sh"
export IMPORT_USERS_SCRIPT_FILE="/opt/import_users.sh"
export MAIN_CONFIG_FILE="/etc/aws-ec2-ssh.conf"
export MAIN_STATE_FILE="/etc/aws-ec2-ssh.state"

IAM_GROUPS=""
IAM_GROUPS_TAG=""
SUDO_GROUPS=""
SUDO_GROUPS_TAG=""
LOCAL_GROUPS=""
LOCAL_GROUP_MAP=""
LOCAL_GROUP_MAP_TAG=""
ASSUME_ROLE=""
USERADD_PROGRAM=""
USERADD_ARGS=""
RELEASE="master"

LOCAL_MARKER_GROUP="iam-synced-users"
CLEAN_STATE="0"
STATE_SYNCED_USERS=""
STATE_MANAGED_GROUPS=""

if [ $# == 0 ] ; then
	echo "No input arguments provided. Please provide one or more input arguments."
	show_help
	exit 1
fi

#Process input arguments with GNU getopt to support long args
OPTS=`getopt -o hva:r: --l "assume:,import-groups:,import-groups-tag:,sudo-groups:,sudo-groups-tag:,local-groups:,local-group-map:,local-group-map-tag:,useradd-program:,useradd-args:,release:,help" \
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
        --local-group-map )
            LOCAL_GROUP_MAP="$2"
            shift 2;;
        --local-group-map-tag )
            LOCAL_GROUP_MAP_TAG="$2"
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
        --local-marker-group )
            LOCAL_MARKER_GROUP="$2"
            shift 2;;
        --clean-state )
            CLEAN_STATE="1"
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

# Get space-separated list of users in local group (defined as input argument)
function get_localgroup_users() {
    get_group_members='/usr/bin/getent group $1 | cut -d : -f4- | sed "s/,/ /g"'

    bash -c "$get_group_members" -- "$1"
}

if [ $CLEAN_STATE != "0" ] && [ -f $MAIN_STATE_FILE ]
then
     . $MAIN_STATE_FILE
fi

cp authorized_keys_command.sh $AUTHORIZED_KEYS_COMMAND_FILE
cp import_users.sh $IMPORT_USERS_SCRIPT_FILE

#Write config file
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

if [ "${LOCAL_GROUP_MAP}" != "" ]
then
    echo "LOCAL_GROUP_MAP='${LOCAL_GROUP_MAP}'" >> $MAIN_CONFIG_FILE
fi

if [ "${LOCAL_GROUP_MAP_TAG}" != "" ]
then
    echo "LOCAL_GROUP_MAP_TAG=\"${LOCAL_GROUP_MAP_TAG}\"" >> $MAIN_CONFIG_FILE
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

# If LOCAL_MARKER_GROUP exists, transfer members to state file (legacy transfer support)
if [ ! -z $LOCAL_MARKER_GROUP ] && getent group "${LOCAL_MARKER_GROUP}" >/dev/null 2>&1
then
    echo "Transfering users from $LOCAL_MARKER_GROUP to state file $MAIN_STATE_FILE..."
    # Transfer users to state file
    STATE_SYNCED_USERS=$(get_localgroup_users "$LOCAL_MARKER_GROUP")

    # Delete group $LOCAL_MARKER_GROUP
    delete_group='groupdel $1'
    bash -c "$delete_group" -- "$LOCAL_MARKER_GROUP"
fi

#Write state file
cat /dev/null > $MAIN_STATE_FILE
echo "STATE_SYNCED_USERS=\"$STATE_SYNCED_USERS\"" >> $MAIN_STATE_FILE
if [ ! -z $STATE_MANAGED_GROUPS ]; then
    echo "STATE_MANAGED_GROUPS=\"$STATE_MANAGED_GROUPS\"" >> $MAIN_STATE_FILE
fi

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
