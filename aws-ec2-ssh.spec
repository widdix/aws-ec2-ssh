%define name aws-ec2-ssh
%define version 0
%define unmangled_version 0
%define release 1.20170427.git.5a15fc6%{?dist}


Name:       %{name}
Summary:    Manage AWS EC2 SSH access with IAM
Version:    %{version}
Release:    %{release}

Group:      System/Administration
License:    MIT
URL:        https://cloudonaut.io/manage-aws-ec2-ssh-access-with-iam/
Source0:    %{name}-%{unmangled_version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
BuildRoot:  %{_tmppath}/%{name}-root}
Vendor:     widdix GmbH
Packager:   Michiel van Baak

Requires:   bash

%description
Use your IAM user's public SSH key to get access via SSH to an EC2 instance.


%prep
%setup -q


%build


%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}%{_bindir}
mkdir -p ${RPM_BUILD_ROOT}/etc/sysconfig
install -m 755 import_users.sh ${RPM_BUILD_ROOT}%{_bindir}
install -m 755 authorized_keys_command.sh ${RPM_BUILD_ROOT}%{_bindir}
install -m 755 aws-ec2-ssh.conf ${RPM_BUILD_ROOT}/etc/aws-ec2-ssh.conf

%post
sed -i 's:#AuthorizedKeysCommand none:AuthorizedKeysCommand /usr/bin/authorized_keys_command.sh:g' /etc/ssh/sshd_config
sed -i 's:#AuthorizedKeysCommandUser nobody:AuthorizedKeysCommandUser nobody:g' /etc/ssh/sshd_config
/etc/init.d/sshd restart


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
%config /etc/aws-ec2-ssh.conf


%changelog

* Thu Apr 27 2017 Michiel van Baak <michiel@vanbaak.eu> - post-1.0-master
- use correct versioning based on fedora package versioning guide

* Sat Apr 15 2017 Michiel van Baak <michiel@vanbaak.eu> - pre-1.0
- Initial RPM spec file
