#!/bin/bash -e

if [ -z "$1" ]; then
  exit 1
fi

SaveUserName="$1"
SaveUserName=${SaveUserName//"+"/".plus."}
SaveUserName=${SaveUserName//"="/".equal."}
SaveUserName=${SaveUserName//","/".comma."}
SaveUserName=${SaveUserName//"@"/".at."}

# Specify IAM group(s) separated by spaces to import users.
# Specify "##ALL##" (including the double quotes) to import all users
IAMGroup=("##ALL##")

[ -z "$IAMGroup" ] && IAMGroup="##ALL##"          # Check for empty ImportGroup

for group in ${IAMGroup[@]}; do
  # Generalizing Query String to avoid multiple conditional loops
  if [ -n "${IAMGroup}" ] && [ "${IAMGroup}" != "##ALL##" ]; then
    queryStr="get-group --group-name $group"
  else
    queryStr="list-users"
  fi

  for user in $( aws iam $queryStr --query "Users[].[UserName]" --output text ); do
    if [ $user == $SaveUserName ]; then
      for KeyId in $( aws iam list-ssh-public-keys --user-name "$SaveUserName" --query "SSHPublicKeys[?Status == 'Active'].[SSHPublicKeyId]" --output text ); do
        aws iam get-ssh-public-key --user-name "$SaveUserName" --ssh-public-key-id "$KeyId" --encoding SSH --query "SSHPublicKey.SSHPublicKeyBody" --output text
      done
      break
    fi
  done
done
