#!/bin/bash

# Assume a role before contacting AWS IAM to get users and keys.
# This can be used if you define your users in one AWS account, while the EC2
# instance you use this script runs in another.
AssumeRole=""

if [[ ! -z "${AssumeRole}" ]]
then

    STSCredentials=$(aws sts assume-role \
        --role-arn "${AssumeRole}" \
        --role-session-name something \
        --query '[Credentials.SessionToken,Credentials.AccessKeyId,Credentials.SecretAccessKey]' \
        --output text)

    AWS_ACCESS_KEY_ID=$(echo "${STSCredentials}" | awk '{print $2}')
    AWS_SECRET_ACCESS_KEY=$(echo "${STSCredentials}" | awk '{print $3}')
    AWS_SESSION_TOKEN=$(echo "${STSCredentials}" | awk '{print $1}')
    AWS_SECURITY_TOKEN=$(echo "${STSCredentials}" | awk '{print $1}')
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
fi

# Specify an IAM group for users who should be given sudo privileges, or leave
# empty to not change sudo access, or give it the value '##ALL##' to have all
# users be given sudo rights.
SudoersGroup=""
[[ -z "${SudoersGroup}" ]] || [[ "${SudoersGroup}" == "##ALL##" ]] || Sudoers=$(
  aws iam get-group --group-name "${SudoersGroup}" --query "Users[].[UserName]" --output text
);

aws iam list-users --query "Users[].[UserName]" --output text | while read User; do
  SaveUserName="$User"
  SaveUserName=${SaveUserName//"+"/".plus."}
  SaveUserName=${SaveUserName//"="/".equal."}
  SaveUserName=${SaveUserName//","/".comma."}
  SaveUserName=${SaveUserName//"@"/".at."}
  if ! grep "^$SaveUserName:" /etc/passwd > /dev/null; then
    /usr/sbin/useradd --create-home --shell /bin/bash "$SaveUserName"
  fi

  if [[ ! -z "${SudoersGroup}" ]]; then
    # sudo will read each file in /etc/sudoers.d, skipping file names that end
    # in ‘~’ or contain a ‘.’ character to avoid causing problems with package
    # manager or editor temporary/backup files.
    SaveUserFileName=$(echo "$SaveUserName" | tr "." " ")
    SaveUserSudoFilePath="/etc/sudoers.d/$SaveUserFileName"
    if [[ "${SudoersGroup}" == "##ALL##" ]] || echo "$Sudoers" | grep "^$User\$" > /dev/null; then
      echo "$SaveUserName ALL=(ALL) NOPASSWD:ALL" > "$SaveUserSudoFilePath"
    else
      [[ ! -f "$SaveUserSudoFilePath" ]] || rm "$SaveUserSudoFilePath"
    fi
  fi
done
