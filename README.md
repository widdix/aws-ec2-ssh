## How does it work

* The iam_user_sync.sh script creates local accounts for all users in ${IAM_AUTHORIZED_GROUPS}, adding them to ${LOCAL_GROUPS}
* All public keys for the users in ${IAM_AUTHORIZED_GROUPS} are downloaded locally to the instance
* SSH is configured to check for authorized keys using sshd's `AuthorizedKeysFile` directive.  In addition to the default
  ${HOME}/.ssh/authorized_keys and ${HOME}/.ssh/authorized_keys2, an additional directory of cached IAM SSH keys is added
  for use with iam_user_sync.sh
* If users are removed from ${IAM_AUTHORIZED_GROUPS} or their keys are deactivated or removed from IAM, the removed
  users/keys are removed from the instance
* The iam_user_sync.sh script is run periodically via cron/systemd

## How to test via CloudFormation

1. Upload your public SSH key to IAM:
 1. Open the Users section in the [IAM Management Console](https://console.aws.amazon.com/iam/home#users)
 1. Click the row with your user
 1. Click the "Upload SSH public key" button at the bottom of the page
 1. Paste your public SSH key into the textarea and click the "Upload SSH public key" button to save
1. Create a stack based on the `cloudformation-example.json` template
1. Wait until the stack status is `CREATE_COMPLETE`
1. Copy the `PublicName` from the stack's outputs
1. Connect via ssh `ssh ${Username}@${PublicName}` replace `${Username}` with your IAM user and `${PublicName}` with the stack's output

## How to integrate this into your environment (via install script)

1. Upload your public SSH key to IAM as above
1. Make sure any instances you want to ssh into contain the correct IAM permissions
(usually based on IAM Profile, but also possibly based on an IAM user and their credentials).
Look at the `policy.json` for an example policy that will permit login.
1. Make sure those instances fetch and run `install.sh`, setting ${IAM_AUTHORIZED_GROUPS} and ${LOCAL_GROUPS} accordingly.  See the script for additional config options (e.g. SCHEDULER=systemd)
1. Connect to your instances now using `ssh ${Username}@${PublicName}` with `${Username}` being your IAM user, and `${PublicName}` being your server's name or IP address.
