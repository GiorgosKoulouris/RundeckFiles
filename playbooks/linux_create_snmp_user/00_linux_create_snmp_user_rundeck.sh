#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd $SCRIPT_DIR

playbookName="linux_create_snmp_user"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

ip="$1"
targetGroup="$2"
snmpUser="$3"
snmpPass="$4"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup linux))
authMethod=${creds[0]}
username=${creds[1]}

if [ "$authMethod" = 'ssh' ]; then
  keyFile=${creds[2]}
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_ssh_private_key_file=$keyFile \
    snmp_user=$snmpUser \
    snmp_pass=$snmpPass"
elif [ "$authMethod" = 'password' ]; then
  passFile=${creds[2]}
  password=$(cat $passFile)
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_password=$password \
    snmp_user=$snmpUser \
    snmp_pass=$snmpPass"
fi
