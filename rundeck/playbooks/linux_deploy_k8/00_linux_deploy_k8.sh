#!/bin/bash

usage() {
    echo
    echo "Usage:"
    echo "    $0 -r <action>                    Runs the specified job(s). Accepted values: all, os-bootstrap, create-user, install-kube, init-cluster"
    echo "    $0 --create-inventory-template    Only creates a template inventory file. No further actions."
    echo
    echo "Other options:"
    echo "    --skip-review     Skips reviews related to ansible functionality (ansible user, ssh keys and inventory). Use BEFORE the -r option."
    echo "    -h, --help        Display this help message."
    echo
}

print_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' .
}

init_vars() {
    INV_FILE="01-hosts.ini"
    SSH_KEY_FILE="./ssh/ansibleUser.key"
    SKIP_GLOBAL_REVIEW='false'
    ANSIBLE_PASSWORD=''
    POPULATE_CONF_TO_USER='false'
}

create_inv_template() {

    echo "; *************************************************************"  >  "$INV_FILE"
    echo "; Please keep the format as it is for the playbook to run     *"  >> "$INV_FILE"
    echo ";                                                             *"  >> "$INV_FILE"
    echo "; controlNode1 is the node initiating the cluster             *"  >> "$INV_FILE"
    echo "; Do not change its name in this file                         *"  >> "$INV_FILE"
    echo "; You can change the rest of host names                       *"  >> "$INV_FILE"
    echo "; *************************************************************"  >> "$INV_FILE"
    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[allNodes:children]"                                              >> "$INV_FILE"
    echo "controlNodes"                                                     >> "$INV_FILE"
    echo "workerNodes"                                                      >> "$INV_FILE"
    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[allNodes:vars]"                                                  >> "$INV_FILE"
    echo "ansible_user="                                                    >> "$INV_FILE"
    echo "ansible_ssh_private_key_file=./ssh/ansibleUser"                   >> "$INV_FILE"
    echo "kubeuser_ssh_public_key_file=./ssh/newUser.pub"                   >> "$INV_FILE"
    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[controlNodes]"                                                   >> "$INV_FILE"
    echo "controlNode1    ansible_host=10.0.10.10   hostname=k8ctl00"       >> "$INV_FILE"
    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[workerNodes]"                                                    >> "$INV_FILE"
    echo "workerNode1     ansible_host=10.0.10.20   hostname=k8wnd00"       >> "$INV_FILE"
    echo "workerNode2     ansible_host=10.0.10.21   hostname=k8wnd01"       >> "$INV_FILE"
}

check_args() {

    if [ $# -eq 0 ]; then
        echo "Missing arguments."
        usage
        exit 1
    fi


    for arg in "$@"; do
        if ([ "$arg" == "--help" ] || [ "$arg" == "-h" ]); then
            usage && exit 0
        fi

        if [ "$arg" == "--create-inventory-template" ]; then
            while true; do
                read -rp "This will overwite the current inventory if ti exists ("$INV_FILE"). Proceed? (y/n): " yn
                case $yn in
                    [Yy]* )
                        create_inv_template
                        echo "Template created ("$INV_FILE")."
                        exit 0
                        ;;
                    [Nn]* )
                        echo "Exiting..."
                        exit 0
                        ;;
                    * )
                        echo "Please answer y or n."
                    ;;
                esac
            done
            exit 0
        fi

        if [ "$arg" == "--skip-review" ]; then
            SKIP_GLOBAL_REVIEW='true'
            shift
        fi       
    done

    echo
    print_line

    BLOCK=""
    echo "Validating arguments..."

    while getopts "r:" opt; do
        case ${opt} in
            r)
                BLOCK=$OPTARG
                ;;           
            *)
                usage
                exit 1
                ;;
        esac
    done

    if [ "$BLOCK" != "all" ] && [ "$BLOCK" != "create-user" ] && [ "$BLOCK" != "install-kube" ] && [ "$BLOCK" != "init-cluster" ]; then
        echo
        echo "'$BLOCK' is not a valid action. Valid actions:"
        echo "  - all"
        echo "  - create-user"
        echo "  - install-kube"
        echo "  - init-cluster"
        usage
        exit 1
    fi

    echo OK
}

validate_files() {
    echo
    print_line
    echo "Validating files..."

    if [ ! -f "$INV_FILE" ]; then
        echo "Host inventory file not found ($INV_FILE)."

        while true; do
            read -rp "Do you want to create a template for the inventory? (y/n): " yn
            case $yn in
                [Yy]* )
                    create_inv_template
                    echo "Inventory template created ($INV_FILE). Edit on the following steps"
                    break
                    ;;
                [Nn]* )
                    echo "Please create a valid inventory file and execute execute the script again"
                    echo "To create an inventory template run: $0 --create-inventory-template"
                    exit 1
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done
    fi

    if [ ! -d "./roles" ]; then
        echo "Roles directory not found (./roles). Exiting..."
        exit 1
    fi

    echo OK
}

review_ansible_options() {
    echo
    print_line
    echo "Reviewing global options..."
    

    [ "$SKIP_GLOBAL_REVIEW" == 'true' ] && echo "Skipping..."

    if [ "$SKIP_GLOBAL_REVIEW" != 'true' ]; then
        echo
        echo "Review the inventory file" && echo
        cat "$INV_FILE" | grep -vE "(^;|^$)"
        echo

        while true; do
            read -rp "Do you need to edit the inventory file? (y/n): " yn
            case $yn in
                [Yy]* )
                    vi "$INV_FILE"
                    break
                    ;;
                [Nn]* )
                    break
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done

        ANSIBLE_USER="$(grep 'ansible_user' "$INV_FILE" | awk -F '=' {'print $2'})"
        SSH_KEY_FILE="$(grep 'ansible_ssh_private_key_file' "$INV_FILE" | awk -F '=' {'print $2'})"

        [ "$ANSIBLE_USER" == '' ] && echo && echo "No username for your ansible user was specified. Exiting..." && exit 1

        if [ ! -f "$SSH_KEY_FILE" ]; then
            echo
            echo "Specified SSH key not found ($SSH_KEY_FILE)."

            while true; do
                read -rp "Create new SSH key (./ssh/ansibleUser and ./ssh/ansibleUser.pub)? (y/n): " yn
                case $yn in
                    [Yy]* )
                        echo "Creating a new SSH key for your ansible user at .ssh/ansibleUser. Please store your private key in a safe place afterwards.";
                        ssh-keygen -t rsa -b 4096 -f "./ssh/ansibleUser" -C "ansibleUser"
                        break
                        ;;
                    [Nn]* )
                        echo "Cannot proceed without a valid key. Exiting..."
                        exit 1
                        ;;
                    * )
                        echo "Please answer y or n."
                        ;;
                esac
            done

        else
            echo
            echo "Specified SSH key for your ansible user found."
            ssh-keygen -y -e -f "$SSH_KEY_FILE" &> /dev/null 
            if [ "$?" -eq 0 ]; then
                echo "Key for user your ansible user is valid."
            else
                echo "The specified SSH key is invalid. Make sure $SSH_KEY_FILE is a valid SSH key."
                echo
                while true; do
                    read -rp "Create new SSH key (./ssh/ansibleUser and ./ssh/ansibleUser.pub)? (y/n): " yn
                    case $yn in
                        [Yy]* )
                            echo "Creating a new SSH key for user ansibleUser at .ssh/ansibleUser. Please store your private key in a safe place afterwards.";
                            ssh-keygen -t rsa -b 4096 -f "./ssh/ansibleUser" -C "$ansibleUser"
                            break
                            ;;
                        [Nn]* )
                            echo "Cannot proceed without a valid key. Exiting..."
                            exit 1
                            ;;
                        * )
                            echo "Please answer y or n."
                            ;;
                    esac
                done
            fi
        fi

        echo

        while true; do
            read -rp "Proceed? (y/n): " yn
            case $yn in
                [Yy]* )
                    break
                    ;;
                [Nn]* )
                    echo "Exiting..."
                    exit 1
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done

    else

        ANSIBLE_USER="$(grep 'ansible_user' "$INV_FILE" | awk -F '=' {'print $2'})"
        SSH_KEY_FILE="$(grep 'ansible_ssh_private_key_file' "$INV_FILE" | awk -F '=' {'print $2'})"

        [ "$ANSIBLE_USER" == '' ] && echo && echo "No username for your ansible user was specified. Exiting..." && exit 1

        if [ ! -f "$SSH_KEY_FILE" ]; then
            echo
            echo "Specified SSH key not found ("$SSH_KEY_FILE"). Exiting..."
            exit 1
        else
            echo
            echo "SSH key for ansible user found."
            ssh-keygen -y -e -f "$SSH_KEY_FILE" &> /dev/null 
            if [ "$?" -eq 0 ]; then
                echo "Key for ansible user is valid."
            else
                echo "The specified SSH key is invalid. Make sure $SSH_KEY_FILE is a valid SSH key."
                echo "Exiting..."
                exit 1
            fi
        fi

        echo
    fi

    read -s -p "Enter become password of your ansible user: " ANSIBLE_PASSWORD
}

os_compatibility_check() {
    echo
    echo
    print_line

    echo "Distros that are currently supported for this action:"
    echo "  - Oracle Linux 8"
    echo "  - Oracle Linux 9"
    echo "  - RedHat 8"
    echo "  - RedHat 9"
    echo "  - Ubuntu 22"
    echo "  - Amazon Linux 2023"
    echo

    while true; do
        read -rp "Are all of your target hosts compatible? (y/n): " yn
        case $yn in
            [Yy]* )
                break
                ;;
            [Nn]* )
                echo "Incompatible OS. Exiting...";
                exit 1
                ;;
            * )
                echo "Please answer y or n."
                ;;
        esac
    done
}

create_user_pre() {
    echo
    print_line
    echo "Kube user options..."
    echo

    read -p "Enter username for the new kubernetes user: " KUBE_USER
    read -s -p "Enter password for $KUBE_USER: " password
    echo

    PASSWORD_HASH=$(ansible all -i localhost, -m debug -a "msg={{ '$password' | password_hash('sha512', 'lefkvhbjekv') }}" | \
        awk -F'"msg": "' '{print $2}' | awk -F'"' '{print $1}' | grep -v "^$")


    grep -q 'kubeuser_ssh_public_key_file' "$INV_FILE"
    if [ "$?" -ne 0 ]; then
        echo
        echo "kubeuser_ssh_public_key_file variable does not exist in inventory file ($INV_FILE)."
        echo "Exiting..."
        exit 1
    fi

    KUBE_SSH_KEY_FILE="$(grep 'kubeuser_ssh_public_key_file' "$INV_FILE" | awk -F '=' {'print $2'})"

    if [ "$KUBE_SSH_KEY_FILE" == "" ]; then
        echo
        echo "kubeuser_ssh_public_key_file variable is set as an empty string ($INV_FILE)."
        echo "Exiting..."
        exit 1
    fi

    if [ ! -f "$KUBE_SSH_KEY_FILE" ]; then
        echo
        echo "Specified SSH key not found ($KUBE_SSH_KEY_FILE)."

        while true; do
            read -rp "Create new SSH key? (./ssh/$KUBE_USER and ./ssh/$KUBE_USER.pub). This will also modify the inventory file to match the new key. (y/n): " yn
            case $yn in
                [Yy]* )
                    echo "Creating a new SSH key for user $KUBE_USER at .ssh/$KUBE_USER. Please store your private key in a safe place afterwards.";
                    ssh-keygen -t rsa -b 4096 -f "./ssh/$KUBE_USER" -C "$KUBE_USER"
                    echo
                    echo "Modifying inventory file"
                    sed -i'' -e "s|kubeuser_ssh_public_key_file=$KUBE_SSH_KEY_FILE|kubeuser_ssh_public_key_file=./ssh/$KUBE_USER.pub|" "$INV_FILE"
                    break
                    ;;
                [Nn]* )
                    echo "Cannot proceed without a valid key. Exiting..."
                    exit 1
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done

    else
        echo
        echo "Specified SSH key for user $KUBE_USER found."
        ssh-keygen -y -e -f "$KUBE_SSH_KEY_FILE" &> /dev/null 
        if [ "$?" -eq 0 ]; then
            echo "Key for user $KUBE_USER is valid."
        else
            echo "The specified SSH key is invalid. Make sure $KUBE_SSH_KEY_FILE is a valid SSH key."
            echo
            while true; do
                read -rp "Create new SSH key? (./ssh/$KUBE_USER and ./ssh/$KUBE_USER.pub). This will also modify the inventory file to match the new key. (y/n): " yn
                case $yn in
                    [Yy]* )
                        echo "Creating a new SSH key for user $KUBE_USER at .ssh/$KUBE_USER. Please store your private key in a safe place afterwards.";
                        ssh-keygen -t rsa -b 4096 -f "./ssh/$KUBE_USER" -C "$KUBE_USER"
                        echo
                        echo "Modifying inventory file"
                        sed -i'' -e "s|kubeuser_ssh_public_key_file=$KUBE_SSH_KEY_FILE|kubeuser_ssh_public_key_file=./ssh/$KUBE_USER.pub|" "$INV_FILE"
                        break
                        ;;
                    [Nn]* )
                        echo "Cannot proceed without a valid key. Exiting..."
                        exit 1
                        ;;
                    * )
                        echo "Please answer y or n."
                        ;;
                esac
            done
        fi
    fi
}

create_user_action() {
    echo
    print_line
    echo "Creating user..."

    ansible-playbook linux_create_user.yml -i "$INV_FILE" \
        --extra-vars "ansible_become_pass='$ANSIBLE_PASSWORD' username=$KUBE_USER password=$PASSWORD_HASH"  || exit 1
}

install_kubernetes_pre() {
    echo
    print_line
    echo "Kubernetes configuration..."
    echo
    
    while true; do
        read -p "Kubernetes version (eg v1.30): " KUBE_VERSION
        case $KUBE_VERSION in
            v1.* )
                break
                ;;
            * )
            echo "Enter a valid version in the format of v1.XX"
            ;;
        esac
    done
}

install_kubernetes_action() {
    echo
    print_line
    echo "Installing kubernetes..."
    ansible-playbook linux_install_kubernetes.yml -i "$INV_FILE" \
        --extra-vars "ansible_become_pass='$ANSIBLE_PASSWORD' k8_version=$KUBE_VERSION"  || exit 1
}

init_cluster_pre() {
    echo
    print_line
    echo "Cluster options..."
    echo "Modify calico options" && sleep 2 && vi './roles/linux_init_kube_cluster/vars/main.yml'

    if [ $BLOCK == 'init-cluster' ]; then
        while true; do
            read -rp "Do you want to populate the cluster config to an existing user? (y/n): " yn
            case $yn in
                [Yy]* )
                    POPULATE_CONF_TO_USER='true'
                    read -p "Enter the username of the user: " KUBE_USER
                    break
                    ;;
                [Nn]* )
                    POPULATE_CONF_TO_USER='false'
                    break
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done

    elif [ $BLOCK == 'all' ]; then
        while true; do
            read -rp "Do you want to populate the cluster to user $KUBE_USER? (y/n): " yn
            case $yn in
                [Yy]* )
                    POPULATE_CONF_TO_USER='true'
                    break
                    ;;
                [Nn]* )
                    POPULATE_CONF_TO_USER='false'
                    break
                    ;;
                * )
                    echo "Please answer y or n."
                    ;;
            esac
        done
    fi
}

init_cluster_action() {
    echo
    print_line
    echo "Initializing cluster..."

    HOSTFILE_BLOCK=$(grep hostname 01-hosts.ini| grep -Ev "(^;|^#)" |awk '{print $2, $3}' | awk -F= '{print $2, $3}' | awk '{print $1, $3}')
    HOSTFILE_TEMP_FILE='./roles/linux_init_kube_cluster/vars/hosts.tmp'
    echo "$HOSTFILE_BLOCK" > "$HOSTFILE_TEMP_FILE"

    ansible-playbook linux_init_kube_cluster.yml -i "$INV_FILE" --extra-vars \
        "ansible_become_pass='$ANSIBLE_PASSWORD' kube_user=$KUBE_USER \
        populate_conf=$POPULATE_CONF_TO_USER cluster_hostfiles=$HOSTFILE_TEMP_FILE"

    rm -f $HOSTFILE_TEMP_FILE
    if [ "$?" != '0' ]; then exit 1; fi
}

execute_all() {
    create_user_pre
    install_kubernetes_pre
    init_cluster_pre

    create_user_action
    install_kubernetes_action
    init_cluster_action
}

main() {
    init_vars
    check_args $@
    validate_files
    review_ansible_options  

    # Execute the appropriate block based on the argument
    case $BLOCK in
        all)
            os_compatibility_check
            execute_all
            ;;
        create-user)
            create_user_pre
            create_user_action
            ;;
        install-kube)
            os_compatibility_check
            install_kubernetes_pre
            install_kubernetes_action
            ;;
        init-cluster)
            init_cluster_pre
            init_cluster_action
            ;;
        *)
            usage
            ;;
    esac
}

main $@