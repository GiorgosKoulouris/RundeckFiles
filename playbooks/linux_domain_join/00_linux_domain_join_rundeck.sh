#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd $SCRIPT_DIR

playbookName="linux_domain_join"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

ip="$1"
targetGroup="$2"
join_domain="$3"
join_user="$4"
join_password="$5"
allowed_groups="$6"

creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $targetGroup linux))
authMethod=${creds[0]}
username=${creds[1]}

if [ "$authMethod" = 'ssh' ]; then
  keyFile=${creds[2]}
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_ssh_private_key_file=$keyFile \
    join_domain=$join_domain \
    join_user=$join_user \
    join_password=$join_password \
    allowed_groups=$allowed_groups"
elif [ "$authMethod" = 'password' ]; then
  passFile=${creds[2]}
  password=$(cat $passFile)
  /var/lib/rundeck/.local/bin/ansible-playbook -i "$ip," $playbookFile \
    -e "ansible_user=$username \
    ansible_password=$password \
    join_domain=$join_domain \
    join_user=$join_user \
    join_password=$join_password \
    allowed_groups=$allowed_groups"
fi

# ./00_linux_domain_join_rundeck.sh 10.0.10.20 AWS-TEST-ENV tcop.local gkadmin 'Ma*empalit\$aAderf3' "OS-Admins,Linux-Admins"
