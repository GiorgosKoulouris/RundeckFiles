#!/bin/bash

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd $SCRIPT_DIR

playbookName="win_promote_to_dc_existing_domain"
playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

TARGET_GROUP="$1"
creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $TARGET_GROUP windows))
USERNAME=${creds[0]}
passFile=${creds[1]}
PASSWORD=$(cat $passFile)

ip="$2"
hostname="$3"
domain="$4"
site_name="$5"
domain_admin_username="$6"
domain_admin_password="$7"
safe_mode_password="$8"

/var/lib/rundeck/.local/bin/ansible-playbook "$playbookFile" -i "$ip," -e \
	"ansible_user=$USERNAME \
	ansible_password=$PASSWORD \
	hostname=$hostname \
	domain=$domain \
	domain_admin_username=$domain_admin_username \
	domain_admin_password=$domain_admin_password \
	site_name=$site_name \
	safe_mode_password=$safe_mode_password \
	ansible_connection=winrm \
	ansible_winrm_transport=basic \
	ansible_winrm_scheme=http \
	ansible_winrm_server_cert_validation=ignore \
	ansible_port=5985 \
	ansible_shell_type=cmd"

