#!/bin/bash

# Which IAM groups have access to this instance
# Comma seperated list of IAM groups. Leave empty for all available IAM users
IAM_AUTHORIZED_GROUPS=""

# Special group to mark users as being synced by our script
LOCAL_MARKER_GROUP="iam-synced-users"

# Give the users these local UNIX groups
LOCAL_GROUPS=""

# Specify an IAM group for users who should be given sudo privileges, or leave
# empty to not change sudo access, or give it the value '##ALL##' to have all
# users be given sudo rights.
SUDOERSGROUP=""

# Assume a role before contacting AWS IAM to get users and keys.
# This can be used if you define your users in one AWS account, while the EC2
# instance you use this script runs in another.
ASSUMEROLE=""

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

# Get all IAM users (optionally limited by IAM groups)
function get_iam_users() {
    local group
    if [ -z "${IAM_AUTHORIZED_GROUPS}" ]
    then
        aws iam list-users \
            --query "Users[].[UserName]" \
            --output text \
        | sed "s/\r//g"
    else
        for group in $(echo ${IAM_AUTHORIZED_GROUPS} | tr "," " "); do
            aws iam get-group \
                --group-name "${group}" \
                --query "Users[].[UserName]" \
                --output text \
            | sed "s/\r//g"
        done
    fi
}

# Get previously synced users
function get_local_users() {
    /usr/bin/getent group ${LOCAL_MARKER_GROUP} \
        | cut -d : -f4- \
        | sed "s/,/ /g"
}

function get_sudoers_users() {
    [[ -z "${SUDOERSGROUP}" ]] || [[ "${SUDOERSGROUP}" == "##ALL##" ]] ||
        aws iam get-group \
            --group-name "${SUDOERSGROUP}" \
            --query "Users[].[UserName]" \
            --output text
}

# Create or update a local user based on info from the IAM group
function create_or_update_local_user() {
    local iamusername
    local username
    local sudousers
    local localusergroups

    iamusername="${1}"
    username="${2}"
    sudousers="${3}"
    localusergroups="${LOCAL_MARKER_GROUP}"

    if [ ! -z "${LOCAL_GROUPS}" ]
    then
        localusergroups="${LOCAL_GROUPS},${LOCAL_MARKER_GROUP}"
    fi

    id "${username}" >/dev/null 2>&1 \
        || /usr/sbin/useradd --create-home --shell /bin/bash "${username}" \
        && /bin/chown -R "${username}:${username}" "/home/${username}"
    /usr/sbin/usermod -G "${localusergroups}" "${username}"

    # Should we add this user to sudo ?
    if [[ ! -z "${SUDOERSGROUP}" ]]
    then
        SaveUserFileName=$(echo "${username}" | tr "." " ")
        SaveUserSudoFilePath="/etc/sudoers.d/$SaveUserFileName"
        if [[ "${SUDOERSGROUP}" == "##ALL##" ]] || echo "${sudousers}" | grep "^${iamusername}\$" > /dev/null
        then
            echo "${SaveUserName} ALL=(ALL) NOPASSWD:ALL" > "${SaveUserSudoFilePath}"
        else
            [[ ! -f "${SaveUserSudoFilePath}" ]] || rm "${SaveUserSudoFilePath}"
        fi
    fi
}

function delete_local_user() {
    /usr/sbin/usermod -L -s /sbin/nologin "${1}"
    /usr/bin/pkill -KILL -u "${1}"
    /usr/sbin/userdel -r "${1}"
}

function clean_iam_username() {
    local clean_username="${1}"
    clean_username=${clean_username//"+"/".plus."}
    clean_username=${clean_username//"="/".equal."}
    clean_username=${clean_username//","/".comma."}
    clean_username=${clean_username//"@"/".at."}
    echo "${clean_username}"
}

function sync_accounts() {
    if [ -z "${LOCAL_MARKER_GROUP}" ]
    then
        echo "Please specify a local group to mark imported users. eg iam-synced-users"
        exit 1
    fi

    # Check if local marker group exists, if not, create it
    /usr/bin/getent group "${LOCAL_MARKER_GROUP}" >/dev/null 2>&1 || /usr/sbin/groupadd "${LOCAL_MARKER_GROUP}"

    # setup the aws credentials if needed
    setup_aws_credentials

    # declare and set some variables
    local iam_users
    local sudo_users
    local local_users
    local intersection
    local removed_users
    local user

    iam_users=$(get_iam_users | sort | uniq)
    sudo_users=$(get_sudoers_users | sort | uniq)
    local_users=$(get_local_users | sort | uniq)

    intersection=$(echo ${local_users} ${iam_users} | tr " " "\n" | sort | uniq -D | uniq)
    removed_users=$(echo ${local_users} ${intersection} | tr " " "\n" | sort | uniq -u)

    # Add or update the users found in IAM
    for user in ${iam_users}; do
        SaveUserName=$(clean_iam_username "${user}")
        create_or_update_local_user "${user}" "${SaveUserName}" "$sudo_users"
    done

    # Remove users no longer in the IAM group(s)
    for user in ${removed_users}; do
        delete_local_user "${user}"
    done
}

sync_accounts
