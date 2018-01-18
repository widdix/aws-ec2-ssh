#!/bin/bash -e

# In order to support SELinux in Enforcing mode, we need to tell SELinux that it
# should have the nis_enabled boolean turned on (so it should expect login services
# like PAM and sshd to make calls to get public keys from a remote server)
#
# This is observed on CentOS 7 and RHEL 7

# Capture the return code and use that to determine if we have the command available
retval=0
which getenforce > /dev/null 2>&1 || retval=$?

if [[ "$retval" -eq "0" ]]; then
  retval=0
  selinuxenabled || retval=$?
  if [[ "$retval" -eq "0" ]]; then
    setsebool -P nis_enabled on
  fi
fi
