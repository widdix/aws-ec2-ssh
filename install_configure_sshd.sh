#!/bin/bash -e

if ! grep -q '^AuthorizedKeysCommand /opt/authorized_keys_command.sh' /etc/ssh/sshd_config; then
	sed -e '/AuthorizedKeysCommand / s/^#*/#/' -i /etc/ssh/sshd_config; echo 'AuthorizedKeysCommand /opt/authorized_keys_command.sh' >> /etc/ssh/sshd_config
fi

if ! grep -q '^AuthorizedKeysCommandUser nobody' /etc/ssh/sshd_config; then
	sed -e '/AuthorizedKeysCommandUser / s/^#*/#/' -i /etc/ssh/sshd_config; echo 'AuthorizedKeysCommandUser nobody' >> /etc/ssh/sshd_config
fi
