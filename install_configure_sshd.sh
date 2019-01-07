#!/bin/bash -e

# add new line if file does not end with new line
if [ -n "$(tail -c1 ${SSHD_CONFIG_FILE})" ]; then
	echo >> ${SSHD_CONFIG_FILE}
fi

if ! grep -q '^AuthorizedKeysCommand /opt/authorized_keys_command.sh' ${SSHD_CONFIG_FILE}; then
	sed -e '/AuthorizedKeysCommand / s/^#*/#/' -i ${SSHD_CONFIG_FILE}; echo "AuthorizedKeysCommand ${AUTHORIZED_KEYS_COMMAND_FILE}" >> ${SSHD_CONFIG_FILE}
fi

if ! grep -q '^AuthorizedKeysCommandUser nobody' ${SSHD_CONFIG_FILE}; then
	sed -e '/AuthorizedKeysCommandUser / s/^#*/#/' -i ${SSHD_CONFIG_FILE}; echo 'AuthorizedKeysCommandUser nobody' >> ${SSHD_CONFIG_FILE}
fi
