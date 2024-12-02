#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd $SCRIPT_DIR

playbookName="linux_create_user"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

ip="$1"
targetGroup="$2"
user_username="$3"
user_password="$4"
user_sshKeyFile="$5"
sudoCommand="$6"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup linux))
authMethod=${creds[0]}
username=${creds[1]}

if [ "$authMethod" = 'ssh' ]; then
  keyFile=${creds[2]}
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_ssh_private_key_file=$keyFile \
    username=$user_username \
    password=$user_password
    ssh_key=$user_sshKeyFile \
    sudo_command='$sudoCommand'"
elif [ "$authMethod" = 'password' ]; then
  passFile=${creds[2]}
  password=$(cat $passFile)
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_password=$password \
    username=$user_username \
    password=$user_password
    ssh_key=$user_sshKeyFile \
    sudo_command='$sudoCommand'"
fi
