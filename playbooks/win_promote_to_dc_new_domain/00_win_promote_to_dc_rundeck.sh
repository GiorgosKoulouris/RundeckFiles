#!/bin/bash

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd $SCRIPT_DIR

init_vars() {

	playbookName="win_promote_to_dc"
	playbooksDir=/rundeck/playbooks
	playbookFile="$playbooksDir/$playbookName/$playbookName.yml"
	inventoryBaseDir=/rundeck/inventories
	timestamp=$(date +"%Y%m%d_%H%M")
	INV_FILE="${inventoryBaseDir}/${playbookName}_newDomain_single-${timestamp}.ini"

	HOSTVARS_PATH="./roles/win_promote_to_dc/vars/hostvars"

	TARGET_GROUP="$1"
	creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $TARGET_GROUP windows))
	USERNAME=${creds[0]}
	passFile=${creds[1]}
	PASSWORD=$(cat $passFile)

	IP="$2"
	HOSTNAME="$3"
	DOMAIN="$4"
	NETBIOS="$5"
	MODE="$6"
	SAFEMODEPASS="$7"
}

create_files_single() {
	echo "[windows]"        > $INV_FILE
	echo "$IP"      >> $INV_FILE

	echo    >> $INV_FILE
	echo "[windows:vars]"   >> $INV_FILE
	echo "ansible_connection=winrm" >> $INV_FILE
	echo "ansible_winrm_transport=basic"    >> $INV_FILE
	echo "ansible_winrm_scheme=http"        >> $INV_FILE
	echo "ansible_winrm_server_cert_validation=ignore"      >> $INV_FILE
	echo "ansible_port=5985"        >> $INV_FILE
	echo "ansible_shell_type=cmd"   >> $INV_FILE

}

execute_single() {
	/var/lib/rundeck/.local/bin/ansible-playbook win_promote_to_dc.yml -i "$INV_FILE" -e \
		"ansible_user=$USERNAME \
		ansible_password=$PASSWORD \
		hostname=$HOSTNAME \
		domain=$DOMAIN
		netbios=$NETBIOS
		mode=$MODE
		safemodepass=$SAFEMODEPASS"
}

main() {
	init_vars $@
	create_files_single
	execute_single

	rm -f "$INV_FILE"
}

main $@
