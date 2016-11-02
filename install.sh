#!/bin/bash -ex

INSTALL_PREFIX=${INSTALL_PREFIX:-/usr/local}
PATH=${INSTALL_PREFIX}/bin:${PATH}

REPO=${REPO:-widdix/aws-ec2-ssh}
BRANCH=${BRANCH:-master}

SCHEDULER=${SCHEDULER:-cron}
SSH_CONFIG_FILE=${SSH_CONFIG_FILE:-/etc/ssh/sshd_config}
SSH_AUTHORIZED_KEYS_DIR=${SSH_AUTHORIZED_KEYS_DIR:-/etc/ssh/authorized_keys}
SSH_SERVICE=${SSH_SERVICE:-sshd}
IAM_AUTHORIZED_GROUPS=${IAM_AUTHORIZED_GROUPS:-}
LOCAL_GROUPS=${LOCAL_GROUPS:-}
LOCAL_MARKER_GROUP=${LOCAL_MARKER_GROUP:-iam-user}

export INSTALL_PREFIX PATH REPO BRANCH SCHEDULER SSH_CONFIG_FILE SSH_AUTHORIZED_KEYS_DIR IAM_AUTHORIZED_GROUPS \
       LOCAL_GROUPS LOCAL_MARKER_GROUP

function fetch() {
  curl -sL https://raw.github.com/${REPO}/${BRANCH}/${1}
}

mkdir -p ${INSTALL_PREFIX}/bin
fetch iam_user_sync.sh > ${INSTALL_PREFIX}/bin/iam_user_sync
chmod +x ${INSTALL_PREFIX}/bin/iam_user_sync

mkdir -p ${SSH_AUTHORIZED_KEYS_DIR}
sed -i '/^AuthorizedKeysFile/d' ${SSH_CONFIG_FILE}
sed -i '$a\' ${SSH_CONFIG_FILE}
echo "AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2 ${SSH_AUTHORIZED_KEYS_DIR}/%u" >> ${SSH_CONFIG_FILE}

getent group ${LOCAL_MARKER_GROUP} >/dev/null 2>&1 || groupadd ${LOCAL_MARKER_GROUP}

case $SCHEDULER in
cron)
  fetch iam_user_sync.cron |
    sed "s|@@SSH_AUTHORIZED_KEYS_DIR@@|${SSH_AUTHORIZED_KEYS_DIR}|g" |
    sed "s|@@IAM_AUTHORIZED_GROUPS@@|${IAM_AUTHORIZED_GROUPS}|g" |
    sed "s|@@LOCAL_GROUPS@@|${LOCAL_GROUPS}|g" |
    sed "s|@@LOCAL_MARKER_GROUP@@|${LOCAL_MARKER_GROUP}|g" |
    sed "s|@@INSTALL_PREFIX@@|${INSTALL_PREFIX}|g" |
    sed "s|@@PATH@@|${PATH}|g" > /etc/cron.d/iam_user_sync
  chmod 0644 /etc/cron.d/iam_user_sync
  ;;
systemd)
  fetch iam_user_sync.service |
    sed "s|@@SSH_AUTHORIZED_KEYS_DIR@@|${SSH_AUTHORIZED_KEYS_DIR}|g" |
    sed "s|@@IAM_AUTHORIZED_GROUPS@@|${IAM_AUTHORIZED_GROUPS}|g" |
    sed "s|@@LOCAL_GROUPS@@|${LOCAL_GROUPS}|g" |
    sed "s|@@LOCAL_MARKER_GROUP@@|${LOCAL_MARKER_GROUP}|g" |
    sed "s|@@INSTALL_PREFIX@@|${INSTALL_PREFIX}|g" |
    sed "s|@@PATH@@|${PATH}|g" > /etc/systemd/system/iam_user_sync.service
  fetch iam_user_sync.timer > /etc/systemd/system/iam_user_sync.timer
  chmod 0644 /etc/systemd/system/iam_user_sync.{service,timer}
  systemctl daemon-reload
  systemctl enable iam_user_sync.timer
  systemctl start iam_user_sync.timer
  ;;
*)
  echo "Unknown scheduler: ${SCHEDULER}" >&1
  exit 1
  ;;
esac

${INSTALL_PREFIX}/bin/iam_user_sync
command -v service && service ${SSH_SERVICE} restart || true
