#!/bin/bash


init_vars() {
	DEFAULT_CSV_FILE="./01-hostInfo.csv"
	CSV_FILE="./01-hostInfo.csv"
	INI_FILE="./02-hosts.ini"
	HOSTVARS_PATH="./vars/hostvars"


	EXECUTE_MODE='single'
}

usage() {
    echo
    echo "Examples:"
    echo "	$0			Execute the job against a single server. Information is provided on runtime"
    echo "	$0 --list-mode		Execute the job against a list of servers. CSV file is expected to be $DEFAULT_CSV_FILE"
    echo "	$0 --list-mode -l <file>	Execute the job against a list of servers. Uses <file> as a custom CSV list"
    echo
    echo "Other options:"
    echo "	--create-csv-template	Generate a placeholder CSV file at $DEFAULT_CSV_FILE"
	echo "	--cleanup		Delete all files containing sensitive data"
    echo "	-h, --help		Display this help message."
    echo
    echo "Notes:"
    echo "	If you come across OBJC related errors, execute the following and run the script again:"
    echo "		export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES"
    echo
	echo "	To open winRM connectivity with target hosts and fix authentication issues, execute the following on Powershell on every host you need to promote"
    echo "		Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true"
	echo "		winrm set winrm/config/service '@{AllowUnencrypted="true"}'"
	echo
}

create_csv_template() {
	while true; do
	read -rp "This will overwite the current CSV file if it exists ("$DEFAULT_CSV_FILE"). Proceed? (y/n): " yn
		case $yn in
			[Yy]* )

				echo "ip,hostname,user,password,domain,netbios,mode,safemodepass,empty" > "$DEFAULT_CSV_FILE"
				echo "10.0.10.7,TESTADC00,Administrator,myPassWord,mydomain.local,mydomain,Win2012R2,Welcome12!@," >> "$DEFAULT_CSV_FILE"

				echo "Template created ("$DEFAULT_CSV_FILE")."
				break
				;;
			[Nn]* )
				echo "Exiting..."
				break
				;;
			* )
				echo "Please answer y or n."
				;;
		esac
	done
}

check_args() {

	for arg in "$@"; do
		case "$arg" in
			-h|--help)
				usage
				exit 0
				;;
			--cleanup)
				cleanup
				exit 0
				;;		
			--create-csv-template)
				create_csv_template
				exit 0
				;;
			--list-mode)
				EXECUTE_MODE='list'
				shift
				;;
		esac
	done

	while getopts "[l:]" opt; do
		case ${opt} in
			l)
				if [ "$EXECUTE_MODE" == 'single' ]; then
					echo "Custom CSVs can only be used with the --list option. Exiting..."
					exit 1
				else
					CSV_FILE="$OPTARG"
				fi
				;;
		esac
	done
}

evaluate_csv() {
	if [ "$EXECUTE_MODE" == 'list' ]; then
		if [ ! -f "$CSV_FILE" ]; then
			echo "CSV file not found ($CSV_FILE)."
			echo "You can create a template by running: $0 --create-csv-template"
			echo "Exiting..."
			exit 1
		fi
	fi
}


create_files_single() {

	read -p "Enter target IP: " IP

	USERNAME='Administrator'
	read -p "Enter ansible username (Blank for Administrator): " NEW_USERNAME
	if [ "$NEW_USERNAME" != '' ]; then
		USERNAME=$NEW_USERNAME
	fi

	read -sp "Enter ansible password: " PASSWORD
	echo
	read -p "Enter new hostname: " HOSTNAME
	read -p "Enter domain: " DOMAIN
	read -p "Enter netbios name: " NETBIOS

	MODE=Win2012R2
	read -p "Enter forest and domain mode (Blank for Win2012R2): " NEW_MODE
	if [ "$NEW_MODE" != '' ]; then
		MODE=$NEW_MODE
	fi

	read -sp "Enter safe mode password: " SAFEMODEPASS

	echo "[windows]"	> $INI_FILE
	echo "$IP"			>> $INI_FILE

	echo																			>> $INI_FILE
	echo "[windows:vars]"															>> $INI_FILE
	echo "ansible_connection=winrm"													>> $INI_FILE
	echo "ansible_winrm_transport=basic"											>> $INI_FILE
	echo "ansible_winrm_scheme=http"												>> $INI_FILE
	echo "ansible_winrm_server_cert_validation=ignore"  							>> $INI_FILE
	echo "ansible_port=5985"                            							>> $INI_FILE
	echo "ansible_shell_type=cmd" 													>> $INI_FILE

	echo

	while true; do
		echo
		echo "Please review:"
		echo
		echo "	Target IP:              $IP"
		echo "	Username:               $USERNAME"
		echo "	New hostname:           $HOSTNAME"
		echo "	Domain:                 $DOMAIN"
		echo "	NetBios name:           $NETBIOS"
		echo "	Domain and forest mode: $MODE"
		echo
		read -rp "Proceed (p), Revisit (r) or Abort (a) (p/r/a): " pra
		case $pra in
			[Pp]* )
				break
				;;
			[Rr]* )
				echo
				create_files_single
				break
				;;
			[Aa]* )
				echo "Exiting..."
				exit 0
				;;
			* )
				echo "Please answer p, r or a."
				;;
		esac
	done
}

execute_single() {
	ansible-playbook win_promote_to_dc.yml -i "$INI_FILE" -e \
		"hostname=$HOSTNAME ansible_user=$USERNAME ansible_password=$PASSWORD \
		domain=$DOMAIN netbios=$NETBIOS mode=$MODE safemodepass=$SAFEMODEPASS"
}

create_files_list() {

	echo "[windows]" > $INI_FILE

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
	printf "%s hostname=%s ansible_user=%s ansible_password='\''%s'\''\n", ip, hostname, user, password >> "'$INI_FILE'"
	}
	' $CSV_FILE

	echo                                                >> $INI_FILE
	echo "[windows:vars]"                               >> $INI_FILE
	echo "ansible_connection=winrm"                     >> $INI_FILE
	echo "ansible_winrm_transport=basic"                >> $INI_FILE
	echo "ansible_winrm_scheme=http"                    >> $INI_FILE
	echo "ansible_winrm_server_cert_validation=ignore"  >> $INI_FILE
	echo "ansible_port=5985"                            >> $INI_FILE
	echo "ansible_shell_type=cmd" >> $INI_FILE
}

execute_list() {
	ansible-playbook win_promote_to_dc.yml -i "$INI_FILE" -e "load_hostvars=true"
}

cleanup() {
	find . -name "*.csv" -exec rm -i {} \;
	[ -f "$INI_FILE" ] && rm -i "$INI_FILE"
	[ -d "$HOSTVARS_PATH" ] && rm -ir "$HOSTVARS_PATH"
}

main() {
	init_vars
	check_args $@
	evaluate_csv

	if [ "$EXECUTE_MODE" == 'single' ]; then
		create_files_single
		execute_single
		echo
		echo "Sesitive data may still be present on this system."
		echo "	Consider executing: $0 --cleanup"
		echo
	else
		create_files_list
		execute_list
		echo
		echo "Sesitive data may still be present on this system."
		echo "	Consider executing: $0 --cleanup"
		echo
	fi
}

main $@

