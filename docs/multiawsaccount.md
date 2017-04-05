# Use multiple AWS accounts

If you are using multiple AWS accounts (as you should be, read the best practices)
you probably have one account with all the IAM users, and are using seperate accounts for
your environments.
Support for this is provided using the AssumeRole functionality in AWS.

## Setup IAM account with the IAM users

 * Create a new role with type 'Role for Cross-Account Access'
   and select the option 'Provide access between AWS accounts you own'
 * Put the first 'ec2' account number in 'Account ID' and leave
   'Require MFA' unchecked
 * Skip attaching a policy (we will create our own later)
 * Review the new role and create it

Now we have to provide the correct access to this role.
You can use the `iam_ssh_policy.json` as provided in the root of this repository


## Setup IAM account with the ec2 instances

The EC2 role you use for launching the EC2 instances should have the policy
as listed in `iam_crossaccount_policy.json` file. Replace the account id and role name
in that file with the account id and role you created in the steps above.
