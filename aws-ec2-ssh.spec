%define name aws-ec2-ssh
%define version %{jenkins_version}
%define release %{jenkins_release}%{?dist}
%define archive %{jenkins_archive}
%define archivedir aws-ec2-ssh-%{jenkins_suffix}

Name:       %{name}
Summary:    Manage AWS EC2 SSH access with IAM
Version:    %{version}
Release:    %{release}

Group:      System/Administration
License:    MIT
URL:        https://cloudonaut.io/manage-aws-ec2-ssh-access-with-iam/
Source0:    https://github.com/widdix/aws-ec2-ssh/archive/%{archive}.tar.gz
BuildArch:  noarch
Vendor:     widdix GmbH
Packager:   Michiel van Baak

Requires:   bash

%description
Use your IAM user's public SSH key to get access via SSH to an EC2 instance.


%prep
%setup -q -n %{archivedir}


%build


%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}%{_bindir}
mkdir -p ${RPM_BUILD_ROOT}%{_sysconfdir}/cron.d
install -m 755 import_users.sh ${RPM_BUILD_ROOT}%{_bindir}
install -m 755 authorized_keys_command.sh ${RPM_BUILD_ROOT}%{_bindir}
install -m 644 aws-ec2-ssh.conf ${RPM_BUILD_ROOT}%{_sysconfdir}/aws-ec2-ssh.conf
sed -i 's/DONOTSYNC=0/DONOTSYNC=1/g' ${RPM_BUILD_ROOT}%{_sysconfdir}/aws-ec2-ssh.conf
echo "*/10 * * * * root /usr/bin/import_users.sh" > ${RPM_BUILD_ROOT}%{_sysconfdir}/cron.d/import_users
chmod 0644 ${RPM_BUILD_ROOT}%{_sysconfdir}/cron.d/import_users


%post
if grep -q '#AuthorizedKeysCommand none' /etc/ssh/sshd_config; then
  sed -i "s:#AuthorizedKeysCommand none:AuthorizedKeysCommand /usr/bin/authorized_keys_command.sh:g" /etc/ssh/sshd_config
else
  if ! grep -q "AuthorizedKeysCommand /usr/bin/authorized_keys_command.sh" /etc/ssh/sshd_config; then
    echo "AuthorizedKeysCommand /usr/bin/authorized_keys_command.sh" >> /etc/ssh/sshd_config
  fi
fi
if grep -q '#AuthorizedKeysCommandUser nobody' /etc/ssh/sshd_config; then
  sed -i "s:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g" /etc/ssh/sshd_config
else
  if ! grep -q 'AuthorizedKeysCommandUser nobody' /etc/ssh/sshd_config; then
    echo "AuthorizedKeysCommandUser nobody" >> /etc/ssh/sshd_config
  fi
fi

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

# Restart sshd using an appropriate method based on the currently running init daemon
# Note that systemd can return "running" or "degraded" (If a systemd unit has failed)
# This was observed on the RHEL 7.3 AMI, so it's added for completeness
# systemd is also not standardized in the name of the ssh service, nor in the places
# where the unit files are stored.

# Capture the return code and use that to determine if we have the command available
retval=0
which systemctl > /dev/null 2>&1 || retval=$?

if [[ "$retval" -eq "0" ]]; then
  if [[ (`systemctl is-system-running` =~ running) || (`systemctl is-system-running` =~ degraded) || (`systemctl is-system-running` =~ starting) ]]; then
    if [ -f "/usr/lib/systemd/system/sshd.service" ] || [ -f "/lib/systemd/system/sshd.service" ]; then
      systemctl restart sshd.service
    else
      systemctl restart ssh.service
    fi
  fi
elif [[ `/sbin/init --version` =~ upstart ]]; then
    if [ -f "/etc/init.d/sshd" ]; then
      service sshd restart
    else
      service ssh restart
    fi
else
  if [ -f "/etc/init.d/sshd" ]; then
    /etc/init.d/sshd restart
  else
    /etc/init.d/ssh restart
  fi
fi

echo "To configure the aws-ec2-ssh package, edit /etc/aws-ec-ssh.conf. No users will be synchronized before you did this."


%postun
sed -i 's:AuthorizedKeysCommand /usr/bin/authorized_keys_command.sh:#AuthorizedKeysCommand none:g' /etc/ssh/sshd_config
sed -i 's:AuthorizedKeysCommandUser nobody:#AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config
/etc/init.d/sshd restart


%clean
rm -rf ${RPM_BUILD_ROOT}


%files
%defattr(-,root,root)
%attr(755,root,root) %{_bindir}/import_users.sh
%attr(755,root,root) %{_bindir}/authorized_keys_command.sh
%config %{_sysconfdir}/aws-ec2-ssh.conf
%config %{_sysconfdir}/cron.d/import_users


%changelog

* Wed May 3 2017 Michiel van Baak <michiel@vanbaak.eu> - 1.1.0-2
- Create cron.d file and run import_users on install

* Thu Apr 27 2017 Michiel van Baak <michiel@vanbaak.eu> - post-1.0-master
- use correct versioning based on fedora package versioning guide

* Sat Apr 15 2017 Michiel van Baak <michiel@vanbaak.eu> - pre-1.0
- Initial RPM spec file
