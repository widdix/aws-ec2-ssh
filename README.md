# Manage AWS EC2 SSH access with IAM

Use your IAM user's public SSH key to get access via SSH to an **EC2 instance** running
* Amazon Linux 2017.09
* Amazon Linux 2 2017.12
* Ubuntu 16.04
* SUSE Linux Enterprise Server 12 SP3
* RHEL 7.4
* CentOS 7

`aws-ec2-ssh` depends on the [AWS CLI](https://aws.amazon.com/cli/) and `git` if you use the `install.sh` script.

## How does it work

A picture is worth a thousand words:

![Architecture](./docs/architecture.png?raw=true "Architecture")

* On first start, all IAM users are imported and local UNIX users are created
* The import also runs every 10 minutes (via cron - calls [`import_users.sh`](./import_users.sh))
* You can control which IAM users get a local UNIX user and are therefore able to login
   * all (default)
   * only those in specific IAM groups
* You can control which IAM users are given sudo access
  * none (default)
  * all
  * only those in a specific IAM group
* You can specify the local UNIX groups for the local UNIX users
* You can assume a role before contacting AWS IAM to get users and keys (e.g. if your IAM users are in another AWS account)
* On every SSH login, the EC2 instance tries to fetch the public key(s) from IAM using sshd's `AuthorizedKeysCommand`
* As soon as the public SSH key is deleted from the IAM user a login is no longer possible

### Demo with CloudFormation

1. Upload your public SSH key to IAM: 
   1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
   2. Click the row with your user
   3. Select the **Security Credentials** tab
   4. Click the **Upload SSH public key** button at the bottom of the page
   5. Paste your public SSH key into the text-area and click the **Upload SSH public key** button to save
2. Create a CloudFormation stack based on the `showcase.yaml` template
3. Wait until the stack status is `CREATE_COMPLETE`
4. Copy the `PublicName` from the stack's outputs
5. Connect to the EC2 instance via `ssh $Username@$PublicName` with `$Username` being your IAM user, and `$PublicName` with the stack's output

## How to integrate this system into your environment

### Install via RPM

1. Upload your public SSH key to IAM: 
   1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
   2. Click the row with your user
   3. Select the **Security Credentials** tab
   4. Click the **Upload SSH public key** button at the bottom of the page
   5. Paste your public SSH key into the text-area and click the **Upload SSH public key** button to save
2. Attach the IAM permissions defined in [`iam_ssh_policy.json`](./iam_ssh_policy.json) to the EC2 instances (by creating an IAM role and an Instance Profile)
3. Install the RPM<sup>1</sup>: `rpm -i https://s3-eu-west-1.amazonaws.com/widdix-aws-ec2-ssh-releases-eu-west-1/aws-ec2-ssh-1.7.0-1.el7.centos.noarch.rpm`
4. The configuration file is placed into `/etc/aws-ec2-ssh.conf`
5. The RPM creates a crontab file to run import_users.sh every 10 minutes. This file is placed in `/etc/cron.d/import_users`

> <sup>1</sup>Check the [releases](https://github.com/widdix/aws-ec2-ssh/releases) and use the latest released RPM.

### Install via install.sh script

1. Upload your public SSH key to IAM: 
   1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
   2. Click the row with your user
   3. Select the **Security Credentials** tab
   4. Click the **Upload SSH public key** button at the bottom of the page
   5. Paste your public SSH key into the text-area and click the **Upload SSH public key** button to save
2. Attach the IAM permissions defined in [`iam_ssh_policy.json`](./iam_ssh_policy.json) to the EC2 instances (by creating an IAM role and an Instance Profile)
3. Run the `install.sh` script as `root` on the EC2 instances. Run `install.sh -h` for help.
4. The configuration file is placed into `/etc/aws-ec2-ssh.conf`
5. Connect to your EC2 instances now using `ssh $Username@$PublicName` with `$Username` being your IAM user, and `$PublicName` being your server's name or IP address

## IAM user names and Linux user names

Allowed characters for IAM user names are:
> alphanumeric, including the following common characters: plus (+), equal (=), comma (,), period (.), at (@), underscore (_), and hyphen (-).

Allowed characters for Linux user names are (POSIX ("Portable Operating System Interface for Unix") standard (IEEE Standard 1003.1 2008)):
> alphanumeric, including the following common characters: period (.), underscore (_), and hyphen (-).

Therefore, characters that are allowed in IAM user names but not in Linux user names:
> plus (+), equal (=), comma (,), at (@).

This solution will use the following mapping for those special characters when creating users:
* `+` => `.plus.`
* `=` => `.equal.`
* `,` => `.comma.`
* `@` => `.at.`

So instead of `name@email.com` you will need to use `name.at.email.com` when login via SSH.

Linux user names may only be up to 32 characters long.

## Configuration

There are a couple of things you can configure by editing/creating the file `/etc/aws-ec2-ssh.conf` and adding
one or more of the following lines:

```
ASSUMEROLE="IAM-role-arn"                      # IAM Role ARN for multi account. See below for more info
IAM_AUTHORIZED_GROUPS="GROUPNAMES"             # Comma separated list of IAM groups to import
SUDOERS_GROUPS="GROUPNAMES"                    # Comma seperated list of IAM groups that should have sudo access
IAM_AUTHORIZED_GROUPS_TAG="KeyTag"             # Key Tag of EC2 that contains a Comma separated list of IAM groups to import - IAM_AUTHORIZED_GROUPS_TAG will override IAM_AUTHORIZED_GROUPS, you can use only one of them 
SUDOERS_GROUPS_TAG="KeyTag"                    # Key Tag of EC2 that contains a Comma separated list of IAM groups that should have sudo access - SUDOERS_GROUPS_TAG will override SUDOERS_GROUPS, you can use only one of them
SUDOERSGROUP="GROUPNAME"                       # Deprecated! IAM group that should have sudo access. Please use SUDOERS_GROUPS as this variable will be removed in future release.
LOCAL_MARKER_GROUP="iam-synced-users"          # Dedicated UNIX group to mark imported users. Used for deleting removed IAM users
LOCAL_GROUPS="GROUPNAMES"                      # Comma seperated list of UNIX groups to add the users in
USERADD_PROGRAM="/usr/sbin/useradd"            # The useradd program to use. defaults to `/usr/sbin/useradd`
USERADD_ARGS="--create-home --shell /bin/bash" # Arguments for the useradd program. defaults to `--create-home --shell /bin/bash`
```

The LOCAL_MARKER_GROUP will be created if it does not exist. BEWARE: DO NOT add any manually created users
to this group as they will be deleted in the next sync. This group is used by aws-ec2-ssh to keep track
of what users were imported in the last run.

## Using a multi account strategy with a central IAM user account

If you are using multiple AWS accounts you probably have one AWS account with all the IAM users (I will call it **users account**), and separate AWS accounts for your environments (I will call it **dev account**). Support for this is provided using the AssumeRole functionality in AWS.

### Setup users account

1. In the **users account**, create a new IAM role
2. Select Role Type **Role for Cross-Account Access** and select the option **Provide access between AWS accounts you own**
3. Put the **dev account** number in **Account ID** and leave **Require MFA** unchecked
4. Skip attaching a policy (we will do this soon)
5. Review the new role and create it
6. Select the newly created role
7. In the **Permissions** tab, expand **Inline Policies** and create a new inline policy
8. Select **Custom Policy**
9. Paste the content of the [`iam_ssh_policy.json`](./iam_ssh_policy.json) file and replace `<YOUR_USERS_ACCOUNT_ID_HERE>` with the AWS Account ID of the **users account**.

### Setup dev account

For your EC2 instances, you need a IAM role that allows the `sts:AssumeRole` action

1. In the **dev account**, create a new IAM role
2. Select ROle Type **AWS Service Roles** and select the option **Amazon EC2**
3. Skip attaching a policy (we will do this soon)
4. Review the new role and create it
5. Select the newly created role
6. In the **Permissions** tab, expand **Inline Policies** and create a new inline policy
7. Select **Custom Policy**
8. Paste the content of the [`iam_crossaccount_policy.json`](./iam_crossaccount_policy.json) file and replace `<YOUR_USERS_ACCOUNT_ID_HERE>` with the AWS Account ID of the **users account** and `<YOUR_USERS_ACCOUNT_ROLE_NAME_HERE>` with the IAM rol name that you created in the **users account**
9. Create/edit the file `/etc/aws-ec2-ssh.conf` and add this line: `ASSUMEROLE="IAM-ROLE-ARN` or run the install.sh script with the -a argument

## Limitations

* your EC2 instances need access to the AWS API either via an Internet Gateway + public IP or a Nat Gatetway / instance.
* it can take up to 10 minutes until a new IAM user can log in
* if you delete the IAM user / ssh public key and the user is already logged in, the SSH session will not be closed
* uid's and gid's across multiple servers might not line up correctly (due to when a server was booted, and what users existed at that time). Could affect NFS mounts or Amazon EFS.
* this solution will work for ~100 IAM users and ~100 EC2 instances. If your setup is much larger (e.g. 10 times more users or 10 times more EC2 instances) you may run into two issues:
  * IAM API limitations
  * Disk space issues
* **not all IAM user names are allowed in Linux user names** (e.g. if you use email addresses as IAM user names). See section [IAM user names and Linux user names](#iam-user-names-and-linux-user-names) for further details.
