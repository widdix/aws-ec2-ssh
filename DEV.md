# Developer notes

## Region Maps

To update the region maps execute the following lines in your terminal:

### RegionMapAmazonLinux

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn-ami-hvm-2018.03.0.20211015.1-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapAmazonLinux2

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn2-ami-hvm-2.0.20211005.0-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapUbuntu

Default user: ubuntu

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20210928" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapSUSELinuxEnterpriseServer

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=suse-sles-12-sp3-v20181004-hvm-ssd-x86_64" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapRHEL

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=RHEL-7.4_HVM_GA-20170808-x86_64-2-Hourly2-GP2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapCentOS

Default user: centos

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=CentOS 7.9.2009 x86_64" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

## Building packages

### `.deb` for Ubuntu 16.04

If you want to build a `.deb` package, you can use `fpm`, which requires `ruby`.
To install on Ubuntu 16.04 LTS:
```
apt-get install ruby ruby-dev rubygems build-essential && gem install --no-ri --no-rdoc fpm
```
You can then run `fpm` to execute.

To build the package, run the following (replacing <> values):
```
fpm -t deb -n aws-ec2-ssh -v <VERSION_STAMP> -d bash -d openssh-server -d awscli --license mit -a all -m "<MAINTAINER>" --vendor "widdix GmbH" --url "https://cloudonaut.io/manage-aws-ec2-ssh-access-with-iam/" --description "Manage AWS EC2 SSH access with IAM" --after-install pkg/postinst --after-remove pkg/postrm --config-files /etc/aws-ec2-ssh.conf -s dir  import_users.sh=/usr/bin/ authorized_keys_command.sh=/usr/bin/ aws-ec2-ssh.conf=/etc/ pkg/import_users=/etc/cron.d/
```
You can then have your nice shiny `.deb` available for use.

### `.rpm` for Amazon Linux

To build an RPM, you will need to have both `rpm-build` and `rpmdevtools` packages installed. You will also need a build tree set up by using `rpmdev-setuptree`. This creates the build tree in your home directory.

Then use the following commands to build the package from the repository root.

```
export VERSION=<RELEASED_VERSION_TO_BUILD>
spectool --define="jenkins_version ${VERSION}" --define="jenkins_release 1" --define="jenkins_archive v${VERSION}" --define="jenkins_suffix ${VERSION}" -g -R aws-ec2-ssh.spec
rpmbuild --define="jenkins_version ${VERSION}" --define="jenkins_release 1" --define="jenkins_archive v${VERSION}" --define="jenkins_suffix ${VERSION}" -bb aws-ec2-ssh.spec
```

You will then have an RPM built in `~/rpmbuild/RPMS/noarch/` available for use.
