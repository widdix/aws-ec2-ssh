#!/bin/bash -e

if [ -z "$1" ]; then
  exit 1
fi

# check if AWS CLI exists
if ! [ -x "$(which aws)" ]; then
    echo "aws executable not found - exiting!"
    exit 1
fi

# source configuration if it exists
[ -f /etc/aws-ec2-ssh.conf ] && . /etc/aws-ec2-ssh.conf

# Assume a role before contacting AWS IAM to get users and keys.
# This can be used if you define your users in one AWS account, while the EC2
# instance you use this script runs in another.
: ${ASSUMEROLE:=""}

if [[ ! -z "${ASSUMEROLE}" ]]
then
  STSCredentials=$(aws sts assume-role \
    --role-arn "${ASSUMEROLE}" \
    --role-session-name something \
    --query '[Credentials.SessionToken,Credentials.AccessKeyId,Credentials.SecretAccessKey]' \
    --output text)

  AWS_ACCESS_KEY_ID=$(echo "${STSCredentials}" | awk '{print $2}')
  AWS_SECRET_ACCESS_KEY=$(echo "${STSCredentials}" | awk '{print $3}')
  AWS_SESSION_TOKEN=$(echo "${STSCredentials}" | awk '{print $1}')
  AWS_SECURITY_TOKEN=$(echo "${STSCredentials}" | awk '{print $1}')
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
fi

UnsaveUserName="$1"
UnsaveUserName=${UnsaveUserName//".plus."/"+"}
UnsaveUserName=${UnsaveUserName//".equal."/"="}
UnsaveUserName=${UnsaveUserName//".comma."/","}
UnsaveUserName=${UnsaveUserName//".at."/"@"}

aws iam list-ssh-public-keys --user-name "$UnsaveUserName" --query "SSHPublicKeys[?Status == 'Active'].[SSHPublicKeyId]" --output text | while read -r KeyId; do
  aws iam get-ssh-public-key --user-name "$UnsaveUserName" --ssh-public-key-id "$KeyId" --encoding SSH --query "SSHPublicKey.SSHPublicKeyBody" --output text
done
