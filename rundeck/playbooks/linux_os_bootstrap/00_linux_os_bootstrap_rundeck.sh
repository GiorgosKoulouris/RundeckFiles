#!/bin/bash

playbookName="linux_os_bootstrap"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

inventoryBaseDir=/rundeck/inventories
timestamp=$(date +"%Y%m%d_%H%M")
inventoryFile="${inventoryBaseDir}/${playbookName}-${timestamp}.ini"

ip="$1"
hostname="$2"
targetGroup="$3"
patchNode="$4"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup linux))
authMethod=${creds[0]}
username=${creds[1]}

if [ "$authMethod" = 'ssh' ]; then
  keyFile=${creds[2]}
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_ssh_private_key_file=$keyFile \
    hostname=$hostname \
    patch=$patchNode"
elif [ "$authMethod" = 'password' ]; then
  passFile=${creds[2]}
  password=$(cat $passFile)
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_password=$password \
    hostname=$hostname \
    patch=$patchNode"
fi