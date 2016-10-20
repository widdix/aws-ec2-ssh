#!/bin/bash -ex

SSH_AUTHORIZED_KEYS_DIR=${SSH_AUTHORIZED_KEYS_DIR:-/etc/ssh/authorized_keys}
IAM_AUTHORIZED_GROUPS=${IAM_AUTHORIZED_GROUPS:-}
LOCAL_GROUPS=${LOCAL_GROUPS:-}
LOCAL_MARKER_GROUP=${LOCAL_MARKER_GROUP:-iam-user}

function get_local_users() {
  getent group ${LOCAL_MARKER_GROUP} \
  | cut -d : -f4- \
  | sed "s/,/ /g"
}

function get_remote_users() {
  for group in $(echo ${IAM_AUTHORIZED_GROUPS} | tr "," " "); do
    aws iam get-group \
      --group-name ${group} \
      --query "Users[].[UserName]" \
      --output text \
    | sed "s/\r//g"
  done
}

function create_update_local_user() {
  set +e
  id ${1} >/dev/null 2>&1 || useradd -m ${1}
  usermod -G ${LOCAL_GROUPS},${LOCAL_MARKER_GROUP} ${1}
  set -e
}

function delete_local_user() {
  set +e
  usermod -L -s /sbin/nologin ${1}
  pkill -KILL -u ${1}
  userdel ${1}
  rm -f ${SSH_AUTHORIZED_KEYS_DIR}/${1}
  set -e
}

function gather_user_keys() {
  set +e
  local tmpfile=$(mktemp)
  local key_ids=$(
    aws iam list-ssh-public-keys \
      --user-name ${1} \
      --query "SSHPublicKeys[?Status=='Active'].[SSHPublicKeyId]" \
      --output text \
    | sed "s/\r//g"
  )
  for key_id in ${key_ids}; do
    aws iam get-ssh-public-key \
      --user-name ${1} \
      --ssh-public-key-id ${key_id} \
      --encoding SSH \
      --query "SSHPublicKey.SSHPublicKeyBody" \
      --output text \
    >> ${tmpfile}
  done
  chmod 644 ${tmpfile}
  mv ${tmpfile} ${SSH_AUTHORIZED_KEYS_DIR}/${1}
  set -e
}

function sync_accounts() {
  if [ -z "${IAM_AUTHORIZED_GROUPS}" ]; then
    echo "Must specify one or more comma-separated IAM groups for IAM_AUTHORIZED_GROUPS" 1>&2
    exit 1
  fi

  local local_users=$(get_local_users)
  local remote_users=$(get_remote_users)
  local intersection=$(echo ${local_users} ${remote_users} | tr " " "\n" | sort | uniq -D | uniq)
  local removed_users=$(echo ${local_users} ${intersection} | tr " " "\n" | sort | uniq -u)

  for user in ${remote_users}; do
    create_update_local_user ${user}
    gather_user_keys ${user}
  done

  for user in ${removed_users}; do
    delete_local_user ${user}
  done
}

sync_accounts
