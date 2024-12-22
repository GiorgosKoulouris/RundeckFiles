#!/bin/bash

playbookName="win_install_ssm_agent"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

ip="$1"
targetGroup="$2"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup windows))
USERNAME=${creds[0]}
passFile=${creds[1]}
PASSWORD=$(cat $passFile)

/var/lib/rundeck/.local/bin/ansible-playbook "$playbookFile" -i "$ip," -e \
  "ansible_user=$USERNAME \
  ansible_password=$PASSWORD \
  ansible_connection=winrm \
  ansible_winrm_transport=basic \
  ansible_winrm_scheme=http \
  ansible_winrm_server_cert_validation=ignore \
  ansible_port=5985 \
  ansible_shell_type=cmd"

