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
    if ! setsebool -P nis_enabled on; then
      if which checkmodule > /dev/null 2>&1; then
        tmpdir="$(mktemp -d)"

        cat <<EOF > "$tmpdir/aws-ec2-ssh.te"
module mypol 1.0;

require {
    type sshd_t;
    type usr_t;
    class file { execute execute_no_trans };
}

#============= sshd_t ==============
allow sshd_t usr_t:file { execute execute_no_trans };
EOF
        checkmodule -M -m -o "$tmpdir/aws-ec2-ssh.mod" "$tmpdir/aws-ec2-ssh.te"  > /dev/null 2>&1
        semodule_package -o "$tmpdir/aws-ec2-ssh.pp" -m "$tmpdir/aws-ec2-ssh.mod"  > /dev/null 2>&1
        semodule -i "$tmpdir/aws-ec2-ssh.pp"  > /dev/null 2>&1
        rm -rf "$tmpdir"
      fi
    fi
  fi
fi
