#!/bin/bash

# Which IAM groups have access to this instance
# Comma seperated list of IAM groups. Leave empty for all available IAM users
IAM_AUTHORIZED_GROUPS="developers-devops-senior,developers-core"

# Special group to mark users as being synced by our script
LOCAL_MARKER_GROUP="iam-synced-users"

# Give the users these groups
LOCAL_GROUPS="wheel"

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

# Get all IAM users in the specified groups
function get_iam_users() {
    local group
    for group in $(echo ${IAM_AUTHORIZED_GROUPS} | tr "," " "); do
        aws iam get-group \
            --group-name "${group}" \
            --query "Users[].[UserName]" \
            --output text
    done
}

# Create or update a local user based on info from the IAM group
function create_or_update_local_user() {
    id "${1}" >/dev/null 2>&1 \
        || /usr/sbin/useradd --create-home --shell /bin/bash "${1}" \
        && chown -R "${1}:${1}" "/home/${1}"
    usermod -G "${LOCAL_GROUPS},${LOCAL_MARKER_GROUP}" "${1}"
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
    # Do some basic checks
    if [ -z "${IAM_AUTHORIZED_GROUPS}" ]
    then
        echo "Please specify what IAM groups are authorized on this instance"
        exit 1
    fi

    if [ -z "${LOCAL_MARKER_GROUP}" ]
    then
        echo "Please specify a local group to mark imported users. eg iam-synced-users"
        exit 1
    fi

    # Check if local marker group exists, if not, create it
    getent group "${LOCAL_MARKER_GROUP}" >/dev/null 2>&1 || groupadd "${LOCAL_MARKER_GROUP}"

    # setup the aws credentials if needed
    setup_aws_credentials

    # declare and set some variables
    local iam_users
    local user

    iam_users=$(get_iam_users)
    # Add or update the users found in IAM
    for user in ${iam_users}; do
        SaveUserName=$(clean_iam_username "${user}")
        create_or_update_local_user "${SaveUserName}"
    done

    # Remove users no longer in the IAM group(s)
}

sync_accounts
