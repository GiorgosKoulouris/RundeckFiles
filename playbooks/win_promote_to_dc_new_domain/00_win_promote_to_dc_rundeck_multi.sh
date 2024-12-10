#!/bin/bash

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd $SCRIPT_DIR

init_vars() {

	playbookName="win_promote_to_dc"
	playbooksDir=/rundeck/playbooks
	playbookFile="$playbooksDir/$playbookName/$playbookName.yml"
	inventoryBaseDir=/rundeck/inventories
	timestamp=$(date +"%Y%m%d_%H%M")
	INV_FILE="${inventoryBaseDir}/${playbookName}_newDomain_multi-${timestamp}.ini"

	HOSTVARS_PATH="./vars/hostvars"

	CSV_FILE="$1"

	[ ! -d "$inventoryBaseDir" ] && mkdir "$inventoryBaseDir"
}

create_files_list() {

	echo "[windows]" > $INV_FILE

	[ ! -d "$HOSTVARS_PATH" ] && mkdir -p "$HOSTVARS_PATH"

	awk -F, '
	NR > 1 {
	# Skip the header row
	ip=$1
	hostname=$2
	user=$3
	password=$4
	domain=$5
	netbios=$6
	mode=$7
	safemodepass=$8
	yml_filename="./vars/hostvars/" hostname ".yml"
	printf "domain: %s\nnetbios: %s\nmode: %s\nsafemodepass: %s", \
		domain, netbios, mode, safemodepass > yml_filename

	# Append IP to the INI file
	printf "%s hostname=%s ansible_user=%s ansible_password='\''%s'\''\n", ip, hostname, user, password >> "'$INV_FILE'"
	}
	' $CSV_FILE

	echo                                                >> $INV_FILE
	echo "[windows:vars]"                               >> $INV_FILE
	echo "ansible_connection=winrm"                     >> $INV_FILE
	echo "ansible_winrm_transport=basic"                >> $INV_FILE
	echo "ansible_winrm_scheme=http"                    >> $INV_FILE
	echo "ansible_winrm_server_cert_validation=ignore"  >> $INV_FILE
	echo "ansible_port=5985"                            >> $INV_FILE
	echo "ansible_shell_type=cmd" >> $INV_FILE
}

execute_list() {
	/var/lib/rundeck/.local/bin/ansible-playbook win_promote_to_dc.yml -i "$INV_FILE" -e "load_hostvars=true"
}

main() {
	init_vars $@
	create_files_list
	execute_list

	rm -f "$INV_FILE"
	rm -f "$HOSTVARS_PATH/*"
}

main $@
