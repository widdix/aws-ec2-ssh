#!/bin/bash -e

if grep -q '#AuthorizedKeysCommand none' "$SSHD_CONFIG_FILE"; then
  sed -i "s:#AuthorizedKeysCommand none:AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}:g" "$SSHD_CONFIG_FILE"
else
  if ! grep -q "AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}" "$SSHD_CONFIG_FILE"; then
    echo "AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}" >> "$SSHD_CONFIG_FILE"
  fi
fi

if grep -aq 'AuthorizedKeysCommandUser' "$SSHD_CONFIG_FILE"; then
  if grep -q '#AuthorizedKeysCommandUser nobody' "$SSHD_CONFIG_FILE"; then
    sed -i "s:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g" "$SSHD_CONFIG_FILE"
  else
    if ! grep -q 'AuthorizedKeysCommandUser nobody' "$SSHD_CONFIG_FILE"; then
      echo "AuthorizedKeysCommandUser nobody" >> "$SSHD_CONFIG_FILE"
    fi
  fi
else
  if grep -q '#AuthorizedKeysCommandRunAs nobody' "$SSHD_CONFIG_FILE"; then
    sed -i "s:#AuthorizedKeysCommandRunAs nobody:AuthorizedKeysCommandRunAs nobody:g" "$SSHD_CONFIG_FILE"
  else
    if ! grep -q 'AuthorizedKeysCommandRunAs nobody' "$SSHD_CONFIG_FILE"; then
      echo "AuthorizedKeysCommandRunAs nobody" >> "$SSHD_CONFIG_FILE"
    fi
  fi
fi
