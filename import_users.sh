#!/bin/bash

# Specify an IAM group for users who should be given sudo privileges, or leave
# empty to give no-one sudo access.
SudoersGroup="";
[[ -z "${SudoersGroup}" ]] || Sudoers=$(aws iam get-group --group-name "${SudoersGroup}" --query "Users[].[UserName]" --output text);

aws iam list-users --query "Users[].[UserName]" --output text | while read User; do
  SaveUserName="$User"
  SaveUserName=${SaveUserName//"+"/".plus."}
  SaveUserName=${SaveUserName//"="/".equal."}
  SaveUserName=${SaveUserName//","/".comma."}
  SaveUserName=${SaveUserName//"@"/".at."}
  if ! grep "^$SaveUserName:" /etc/passwd > /dev/null; then
    # sudo will read each file in /etc/sudoers.d, skipping file names that end in ‘~’ or contain a ‘.’ character to avoid causing problems with package manager or editor temporary/backup files.
    /usr/sbin/useradd --create-home --shell /bin/bash "$SaveUserName" 
    # Uncomment the following lines if you need to give all users sudo privileges
    # SaveUserFileName=$(echo "$SaveUserName" | tr "." " ")
    # echo "$SaveUserName ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SaveUserFileName"
  fi

  if [[ ! -z "${SudoersGroup}" ]]; then
    UserIsSudoer="";
    for Sudoer in $Sudoers; do
      if [[ "$Sudoer" == "$User" ]]; then
        UserIsSudoer="yes";
      fi
    done

    SaveUserFileName=$(echo "$SaveUserName" | tr "." " ")
    if [[ "$UserIsSudoer" == "yes" ]]; then
      echo "$SaveUserName ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SaveUserFileName"
    else
      [[ ! -f "/etc/sudoers.d/$SaveUserFileName" ]] || rm "/etc/sudoers.d/$SaveUserFileName"
    fi
  fi
done
