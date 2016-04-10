# Manage AWS EC2 SSH access with IAM

This showcase demonstrates how you can use your IAM user's public ssh key to get access via SSH to an EC2 instance.

## How to tun this showcase

1. Upload your public SSH key to IAM: 
 1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
 1. Click the row with your user
 1. Click the "Upload SSH public key" button at the bottom of the page
 1. Paste your public SSH key into the textarea and click the "Upload SSH public key" button to save
1. Create a stack based on the `showcase.json` template
1. Wait until the stack status is `CREATE_COMPLETE`
1. Copy the `PublicName` from the stack's outputs
1. Connect via ssh `ssh $Username@$PublicName` replace `$Username` with your IAM user and `$PublicName` with the stack's output

## How does it work

* On first start all IAM users are imported and local users are created
 * The import also runs every 10 minutes
* On every SSH login the EC2 instance tries to fetch the public key(s) from IAM using sshd's `AuthorizedKeysCommand`
 * You can restrict that the EC2 instance is only allowed to download public keys from certain IAM users instead of `*`. This way you can restrict SSH access within your account
 * As soon as the public SSH key is deleted from the IAM user a login is no longer possible
