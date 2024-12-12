#!/bin/bash

playbookName="linux_install_zabbix_agent"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

ip="$1"
targetGroup="$2"
version="$3"
serverIP="$4"
statusPort="$5"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup linux))
authMethod=${creds[0]}
username=${creds[1]}

if [ "$authMethod" = 'ssh' ]; then
  keyFile=${creds[2]}
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_ssh_private_key_file=$keyFile \
    hostname=$hostname \
    serverIP=$serverIP \
    statusPort=$statusPort \
    version=$version"
elif [ "$authMethod" = 'password' ]; then
  passFile=${creds[2]}
  password=$(cat $passFile)
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_password=$password \
    hostname=$hostname \
    serverIP=$serverIP \
    statusPort=$statusPort \
    version=$version"
fi
