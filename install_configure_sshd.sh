#!/usr/bin/env bash

set -e

if grep -q '#AuthorizedKeysCommand none' "$SSHD_CONFIG_FILE"; then
  sed -i "s:#AuthorizedKeysCommand none:AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}:g" "$SSHD_CONFIG_FILE"
else
  if ! grep -q "^AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}" "$SSHD_CONFIG_FILE"; then
    echo "AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}" >> "$SSHD_CONFIG_FILE"
  fi
fi

if grep -aq 'AuthorizedKeysCommandUser' "$(which sshd)"; then
  if grep -q '#AuthorizedKeysCommandUser nobody' "$SSHD_CONFIG_FILE"; then
    sed -i "s:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g" "$SSHD_CONFIG_FILE"
  else
    if ! grep -q '^AuthorizedKeysCommandUser nobody' "$SSHD_CONFIG_FILE"; then
      echo "AuthorizedKeysCommandUser nobody" >> "$SSHD_CONFIG_FILE"
    fi
  fi
else
  echo 'AuthorizedKeysCommandUser not supported in sshd_config'
  exit 1
fi
