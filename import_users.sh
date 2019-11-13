#!/bin/bash
set -e -o pipefail

trap "exit 1" TERM	#Trigger error exit when receiving TERM sign
export TOP_PID=$$

function log() {
    /usr/bin/logger -i -p auth.info -t aws-ec2-ssh "$@"
}

function exitlog() {
    log "$@"
    #send TERM sign to script to trigger full exit
    kill -s TERM $TOP_PID
    exit 1
}

# check if AWS CLI exists
if ! [ -x "$(which aws)" ]; then
    exitlog "aws executable not found - exiting!"
fi

# source configuration if it exists
[ -f /etc/aws-ec2-ssh.conf ] && . /etc/aws-ec2-ssh.conf

# source state file if it exists, error otherwise
MAIN_STATE_FILE="/etc/aws-ec2-ssh.state"
if [ -f $MAIN_STATE_FILE ]; then
    . $MAIN_STATE_FILE
else
    exitlog "Please initiate a state file at $MAIN_STATE_FILE"
fi

# Default state values
# Current locally synced users
: ${STATE_SYNCED_USERS:=""}
# Current local groups managed by aws-ec2-ssh
: ${STATE_MANAGED_GROUPS:=""}

# Should we actually do something?
: ${DONOTSYNC:=0}

if [ ${DONOTSYNC} -eq 1 ]
then
    exitlog "Please configure aws-ec2-ssh by editing /etc/aws-ec2-ssh.conf"
fi

# Which IAM groups have access to this instance
# Comma seperated list of IAM groups. Leave empty for all available IAM users
: ${IAM_AUTHORIZED_GROUPS:=""}

# Add all imported users to these local UNIX groups
: ${LOCAL_GROUPS:=""}

# Add specific iam-groups to specific local UNIX groups
: ${LOCAL_GROUP_MAP:=""}

# Specify an IAM group for users who should be given sudo privileges, or leave
# empty to not change sudo access, or give it the value '##ALL##' to have all
# users be given sudo rights.
# DEPRECATED! Use SUDOERS_GROUPS
: ${SUDOERSGROUP:=""}

# Specify a comma seperated list of IAM groups for users who should be given sudo privileges.
# Leave empty to not change sudo access, or give the value '##ALL## to have all users
# be given sudo rights.
: ${SUDOERS_GROUPS:="${SUDOERSGROUP}"}

# Assume a role before contacting AWS IAM to get users and keys.
# This can be used if you define your users in one AWS account, while the EC2
# instance you use this script runs in another.
: ${ASSUMEROLE:=""}

# Possibility to provide a custom useradd program
: ${USERADD_PROGRAM:="/usr/sbin/useradd"}

# Possibility to provide custom useradd arguments
: ${USERADD_ARGS:="--user-group --create-home --shell /bin/bash"}

# Initizalize INSTANCE variable
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

function setup_aws_credentials() {
    local stscredentials
    if [[ ! -z "${ASSUMEROLE}" ]]
    then
        stscredentials=$(aws sts assume-role \
            --role-arn "${ASSUMEROLE}" \
            --role-session-name something \
            --query '[Credentials.SessionToken,Credentials.AccessKeyId,Credentials.SecretAccessKey]' \
            --output text)

        AWS_ACCESS_KEY_ID=$(echo "${stscredentials}" | awk '{print $2}')
        AWS_SECRET_ACCESS_KEY=$(echo "${stscredentials}" | awk '{print $3}')
        AWS_SESSION_TOKEN=$(echo "${stscredentials}" | awk '{print $1}')
        AWS_SECURITY_TOKEN=$(echo "${stscredentials}" | awk '{print $1}')
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
    fi
}

# Get EC2 tag value
function get_ec2_tag_value() {
    local tag_value=$(\
        aws --region $REGION ec2 describe-tags \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$1" \
        --query "Tags[0].Value" --output text \
    )

    if [ $? != 0 ] ; then
        exitlog "Error retrieving EC2 tag value for '$1'."
    fi

    if [ "$tag_value" == "None" ] ; then
        warn_msg="Warning: EC2 tag key '$1' not found."

        echo "$warn_msg" >&2
        log "$warn_msg"

        tag_value=""
    fi

    echo "$tag_value"
}

# Get list of IAM users (in IAM groups if defined as input argument)
# Optional argument: comma-separated list of IAM groups to return IAM users for
function get_iam_users() {
    local grouplist
    if [ ! -z "$1" ]; then
        grouplist=$1
    fi

    local group
    if [ -z "$grouplist" ]
    then
        aws iam list-users \
            --query "Users[].[UserName]" \
            --output text \
          | sed "s/\r//g" \
          || exitlog "Error while retrieving all IAM users."
    else
        for group in $(echo ${grouplist} | tr "," " "); do
            aws iam get-group \
                --group-name "${group}" \
                --query "Users[].[UserName]" \
                --output text \
              | sed "s/\r//g" \
              || exitlog "Error while retrieving IAM users for group '${group}'"
        done
    fi
}

# Check if a certain value can be found in given (new-line separated) list
function in_list() {
    local needle
    local haystack

    needle="${1}"
    haystack="${2}"

    echo "${haystack}" | grep -qx "${needle}"
}

# Create or update a local user based on info from the IAM group
function create_or_update_local_user() {
    local username
    local sudousers
    local localusergroups

    username="${1}"
    sudousers="${2}"

    localusergroups=""
    if [ ! -z "${3}" ]; then
        localusergroups="${localusergroups},${3}"
    fi
    if [ ! -z "${LOCAL_GROUPS}" ]
    then
        localusergroups="${localusergroups},${LOCAL_GROUPS}"
    fi
    localusergroups="${localusergroups:1}"

    # check that username contains only alphanumeric, period (.), underscore (_), and hyphen (-) for a safe eval
    if [[ ! "${username}" =~ ^[0-9a-zA-Z\._\-]{1,32}$ ]]
    then
        exitlog "Local user name ${username} contains illegal characters"
    fi

    if ! id "${username}" >/dev/null 2>&1; then
        ${USERADD_PROGRAM} ${USERADD_ARGS} "${username}"
        /bin/chown -R "${username}:${username}" "$(eval echo ~$username)"
        log "Created new user ${username}"
    fi

    /usr/sbin/usermod -G "${localusergroups}" "${username}"

    # Should we add this user to sudo ?
    if [[ ! -z "${SUDOERS_GROUPS}" ]]
    then
        SaveUserFileName=$(echo "${username}" | tr "." " ")
        SaveUserSudoFilePath="/etc/sudoers.d/$SaveUserFileName"
        if [[ "${SUDOERS_GROUPS}" == "##ALL##" ]] || in_list "${username}" "${sudousers}"
        then
            if [[ ! -f "${SaveUserSudoFilePath}" ]] ; then
                echo "${username} ALL=(ALL) NOPASSWD:ALL" > "${SaveUserSudoFilePath}"
                log "Granted sudo access for user '${username}'"
            fi
        else
            if [[ -f "${SaveUserSudoFilePath}" ]] ; then
                rm "${SaveUserSudoFilePath}"
                log "Revoked sudo access for user '${username}'"
            fi
        fi
    fi
}

# Get space-separated list of users in local group (defined as input argument)
function get_localgroup_users() {
    get_group_members='/usr/bin/getent group $1 | cut -d : -f4- | sed "s/,/ /g"'

    bash -c "$get_group_members" -- "$1"
}

function delete_local_user() {
    # First, make sure no new sessions can be started
    /usr/sbin/usermod -L -s /sbin/nologin "${1}" || true
    # ask nicely and give them some time to shutdown
    /usr/bin/pkill -15 -u "${1}" || true
    sleep 5
    # Dont want to close nicely? DIE!
    /usr/bin/pkill -9 -u "${1}" || true
    sleep 1
    # Remove account now that all processes for the user are gone
    /usr/sbin/userdel -f -r "${1}"
    log "Deleted user ${1}"
}

#Convert iam username(s) to valid UNIX username(s) (converting illegal characters)
function clean_iam_username() {
    while read line; do
        local clean_username="${line}"
        clean_username=${clean_username//"+"/".plus."}
        clean_username=${clean_username//"="/".equal."}
        clean_username=${clean_username//","/".comma."}
        clean_username=${clean_username//"@"/".at."}
        echo "${clean_username}"
    done < "${1:-/dev/stdin}"
}

function sync_accounts() {

    # declare and set some variables
    local iam_users
    local sudo_users
    local local_users
    local synced_users
    local managed_groups
    local intersection
    local removed_users
    local user
    declare -A local_group_users

    # init import-groups, sudoers and group-map from tags
    if [ "${IAM_AUTHORIZED_GROUPS_TAG}" ]
    then
        IAM_AUTHORIZED_GROUPS=$(get_ec2_tag_value "$IAM_AUTHORIZED_GROUPS_TAG")
    fi

    if [ "${SUDOERS_GROUPS_TAG}" ]
    then
        SUDOERS_GROUPS=$(get_ec2_tag_value "$SUDOERS_GROUPS_TAG")
    fi

    if [ "${LOCAL_GROUP_MAP_TAG}" ]
    then
        LOCAL_GROUP_MAP=$(get_ec2_tag_value "$LOCAL_GROUP_MAP_TAG")
    fi

    # init managed_groups from state
    if [ ! -z "$STATE_MANAGED_GROUPS" ]; then
        managed_groups=" $STATE_MANAGED_GROUPS"
    fi

    # setup the aws credentials if needed
    setup_aws_credentials
    
    # Convert all groups to users
    iam_users=$(get_iam_users "${IAM_AUTHORIZED_GROUPS}" | clean_iam_username | sort | uniq)

    if [[ ! -z "${SUDOERS_GROUPS}" ]] && [[ ! "${SUDOERS_GROUPS}" == "##ALL##" ]]
    then
        sudo_users=$(get_iam_users "${SUDOERS_GROUPS}" | clean_iam_username | sort | uniq)
    fi

    local groups
    if [[ ! -z "${LOCAL_GROUP_MAP}" ]]
    then
        get_json_keys='echo "$1" | jq -r "keys []"'
        get_json_valueconcat='echo "$1" | jq -r ".$2 | join(\",\")"'

        groups=$(bash -c "$get_json_keys" -- "${LOCAL_GROUP_MAP}")

        for localgroup in $groups; do
            # Parse the iam-groups
            iam_group_list=$(bash -c "$get_json_valueconcat" -- "${LOCAL_GROUP_MAP}" "${localgroup}")
            # Retrieve the users
            local_group_users[$localgroup]=$(get_iam_users "${iam_group_list}" | clean_iam_username | sort | uniq)
        done
    fi

    # Create local groups if they don't exist yet
    for localgroup in $groups; do
        if ! /usr/bin/getent group "${localgroup}" >/dev/null 2>&1; then
            /usr/sbin/groupadd "${localgroup}"
            managed_groups="$managed_groups $localgroup"
            log "Created local group '${localgroup}'"
        fi
    done

    managed_groups="${managed_groups:1}"

    local_users=$(echo "$STATE_SYNCED_USERS" | tr " " "\n" | sort | uniq)

    intersection=$(echo -e "${local_users}\n${iam_users}" | tr " " "\n" | sort | uniq -D | uniq)
    removed_users=$(echo -e "${local_users}\n${intersection}" | tr " " "\n" | sort | uniq -u)

    # Add or update the users found in IAM
    for user in ${iam_users}; do
        if [ "${#user}" -le "32" ]
        then
            local user_groups
            user_groups=""

            for group in ${!local_group_users[@]}; do
                if in_list "$user" "${local_group_users[$group]}"; then
                    user_groups=${user_groups}",$group"
                fi
            done
            user_groups="${user_groups:1}"

            create_or_update_local_user "${user}" "$sudo_users" "$user_groups"

            synced_users="$synced_users $user"
        else
            log "Can not import IAM user ${user}. User name is longer than 32 characters."
        fi
    done
    STATE_SYNCED_USERS="${synced_users:1}"

    # Remove users no longer in the IAM group(s)
    for user in ${removed_users}; do
        delete_local_user "${user}"
    done

    # Remove script-managed groups no longer having any members
    local remaining_groups=""
    for group in ${managed_groups}; do
        local group_users=$(get_localgroup_users $group)
        if [ -z "$group_users" ]; then
            delgroup --only-if-empty $group
            log "Deleted local group '${group}'"
        else
            remaining_groups="$remaining_groups $group"
        fi
    done
    
    STATE_MANAGED_GROUPS="${remaining_groups:1}"

    # Update state file
    cat /dev/null > $MAIN_STATE_FILE
    echo "STATE_SYNCED_USERS=\"$STATE_SYNCED_USERS\"" >> $MAIN_STATE_FILE
    echo "STATE_MANAGED_GROUPS=\"$STATE_MANAGED_GROUPS\"" >> $MAIN_STATE_FILE
}

sync_accounts
