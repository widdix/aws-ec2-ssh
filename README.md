# Manage AWS EC2 SSH access with IAM

This showcase demonstrates how you can use your IAM user's public SSH key to get access via SSH to an EC2 instance.

## How does it work

A picture is worth a thousand words:

![Architecture](./docs/architecture.png?raw=true "Architecture")

* On first start all IAM users are imported and local users are created
 * The import also runs every 10 minutes (via cron - calls import_users.sh)
 * You can control which users are given sudo access as:
  * none (default)
  * all
  * only those in a specific IAM group.
* On every SSH login the EC2 instance tries to fetch the public key(s) from IAM using sshd's `AuthorizedKeysCommand`
 * You can restrict that the EC2 instance is only allowed to download public keys from certain IAM users instead of `*`. This way you can restrict SSH access within your account
 * As soon as the public SSH key is deleted from the IAM user a login is no longer possible

## How to run this showcase (CloudFormation)

1. Upload your public SSH key to IAM: 
 1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
 1. Click the row with your user
 1. Click the "Upload SSH public key" button at the bottom of the page
 1. Paste your public SSH key into the textarea and click the "Upload SSH public key" button to save
1. Create a stack based on the `showcase.yaml` template
1. Wait until the stack status is `CREATE_COMPLETE`
1. Copy the `PublicName` from the stack's outputs
1. Connect via ssh `ssh $Username@$PublicName` replace `$Username` with your IAM user and `$PublicName` with the stack's output

## How to integrate this system into your environment (non-CloudFormation)

1. Upload your public SSH key to IAM as above
1. Make sure any instances you want to ssh into contain the correct IAM permissions
(usually based on IAM Profile, but also possibly based on an IAM user and their credentials).
Look at the `iam_ssh_policy.json` for an example policy that will permit login.
1. Make sure those instances automatically run a script similar to `install.sh` (note - that script assumes `git` is installed _and_ instances have access to the Internet; feel free to modify it to instead install from a tarball or using any other mechanism such as Chef or Puppet).
 * If you want to control sudo access, you should modify the value of ‘SudoersGroup’ in import_users.sh
1. Connect to your instances now using `ssh $Username@$PublicName` with `$Username` being your IAM user, and `$PublicName` being your server's name or IP address.

## Limitations

* your EC2 instances need access to the AWS API either via an Internet Gateway + public IP or a Nat Gatetway / instance.
* it can take up to 10 minutes until a new IAM user can log in
* if you delete the IAM user / ssh public key and the user is already logged in, the SSH session will not be closed
* uid's and gid's across multiple servers might not line up correctly (due to when a server was booted, and what users existed at that time). Could affect NFS mounts or Amazon EFS.
* this solution will work for ~100 IAM users and ~100 EC2 instances. If your setup is much larger (e.g. 10 times more users or 10 times more EC2 instances) you may run into two issues:
  * IAM API limitations
  * Disk space issues
* not all IAM user names are allowed in Linux user names. See section [IAM user names and Linux user names](#iam-user-names-and-linux-user-names) for further details.

### IAM user names and Linux user names

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
