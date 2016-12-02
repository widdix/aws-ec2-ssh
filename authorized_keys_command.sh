#!/bin/bash -e

if [ -z "$1" ]; then
  exit 1
fi

SaveUserName="$1"
SaveUserName=${SaveUserName//"+"/".plus."}
SaveUserName=${SaveUserName//"="/".equal."}
SaveUserName=${SaveUserName//","/".comma."}
SaveUserName=${SaveUserName//"@"/".at."}

aws iam list-ssh-public-keys --user-name "$SaveUserName" --query "SSHPublicKeys[?Status == 'Active'].[SSHPublicKeyId]" --output text | while read KeyId; do
  aws iam get-ssh-public-key --user-name "$SaveUserName" --ssh-public-key-id "$KeyId" --encoding SSH --query "SSHPublicKey.SSHPublicKeyBody" --output text
done
