#!/bin/bash

playbookName="linux_deploy_k8"

playbooksDir=/rundeck/playbooks
playbookFile="$playbooksDir/$playbookName/$playbookName.yml"

inventoryBaseDir=/rundeck/inventories
timestamp=$(date +"%Y%m%d_%H%M")
INV_FILE="${inventoryBaseDir}/${playbookName}-${timestamp}.ini"

print_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' .
}

init_vars() {
    GROUP="$1"
    CTLNODE_INFO="$2"
    WND_INFO="$3"
    KUBE_VERSION="$4"
    CALICO_INSTALL="$5"
    CREATE_USER="$6"
    KUBE_USER="$7"
    KUBE_SSH_KEY_FILE="$8"

    if [ "$CALICO_INSTALL" = 'none' ]; then
        INSTALL_CALICO=false
        CALICO_VERSION='0'
    else
        INSTALL_CALICO=true
        CALICO_VERSION=$CALICO_INSTALL
    fi
}       
 
create_inventory_file() {
    creds=($(/rundeck/credentials/00_get_rundeck_credentials.sh $GROUP linux))
    authMethod=${creds[0]}
    username=${creds[1]}

    echo "# -------------------------------------"                          >  "$INV_FILE"
    echo "[allNodes:children]"                                              >> "$INV_FILE"
    echo "controlNodes"                                                     >> "$INV_FILE"
    echo "workerNodes"                                                      >> "$INV_FILE"
    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[allNodes:vars]"                                                  >> "$INV_FILE"
    echo "ansible_user=$username"                                           >> "$INV_FILE"

    if [ "$authMethod" = 'ssh' ]; then
        keyFile=${creds[2]}
        echo "ansible_ssh_private_key_file=$keyFile" >> $INV_FILE
    elif [ "$authMethod" = 'password' ]; then
        passFile=${creds[2]}
        password=$(cat $passFile)
        echo "ansible_password=$password" >> $INV_FILE
    fi

    if [ "$CREATE_USER" = 'true' ]; then
        echo "kubeuser_ssh_public_key_file=$KUBE_SSH_KEY_FILE" >> "$INV_FILE"
    fi

    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[controlNodes]"                                                   >> "$INV_FILE"

    ctl_ip="$(echo $CTLNODE_INFO | awk -F',' '{print $1}')"
    ctl_hostname="$(echo $CTLNODE_INFO | awk -F',' '{print $2}')"
    echo "controlNode1    ansible_host=$ctl_ip   hostname=$ctl_hostname"    >> "$INV_FILE"

    echo "# -------------------------------------"                          >> "$INV_FILE"
    echo "[workerNodes]"                                                    >> "$INV_FILE"

    IFS='|' read -ra nodes <<< "$WND_INFO"

    # Loop through each node
    for i in "${!nodes[@]}"; do
        # Split each node on ','
        IFS=',' read -r ip hostname <<< "${nodes[i]}"

        # Prepare the worker node name
        worker_node="workerNode$((i + 1))"

        # Append to the output file
        echo "$worker_node ansible_host=$ip hostname=$hostname" >> "$INV_FILE"
    done
}

create_user_action() {
    echo
    print_line
    echo "Creating user..."

    PASSWORD_HASH=$(ansible all -i localhost, -m debug -a "msg={{ 'pgdbVA8dIe8pSDSSr2BLTc' | password_hash('sha512', 'lefkvhbjekv') }}" | \
        awk -F'"msg": "' '{print $2}' | awk -F'"' '{print $1}' | grep -v "^$")

    /var/lib/rundeck/.local/bin/ansible-playbook $playbooksDir/$playbookName/linux_create_user.yml -i "$INV_FILE" --extra-vars \
        "username=$KUBE_USER \
        password=$PASSWORD_HASH \
        kubeuser_ssh_public_key_file=$KUBE_SSH_KEY_FILE"  || exit 1
}

install_kubernetes_action() {
    echo
    print_line
    echo "Installing kubernetes..."

    /var/lib/rundeck/.local/bin/ansible-playbook $playbooksDir/$playbookName/linux_install_kubernetes.yml -i "$INV_FILE" \
        --extra-vars "k8_version=$KUBE_VERSION"  || exit 1
}

init_cluster_action() {
    echo
    print_line
    echo "Initializing cluster..."

    HOSTFILE_BLOCK=$(grep hostname $INV_FILE | grep -Ev "(^;|^#)" |awk '{print $2, $3}' | awk -F= '{print $2, $3}' | awk '{print $1, $3}')
    HOSTFILE_TEMP_FILE='./roles/linux_init_kube_cluster/vars/hosts.tmp'
    echo "$HOSTFILE_BLOCK" > "$HOSTFILE_TEMP_FILE"

    /var/lib/rundeck/.local/bin/ansible-playbook $playbooksDir/$playbookName/linux_init_kube_cluster.yml -i "$INV_FILE" --extra-vars \
        "kube_user=$KUBE_USER \
        populate_conf=$CREATE_USER \
        cluster_hostfiles=$HOSTFILE_TEMP_FILE \
        install_calico=$INSTALL_CALICO \
        calico_version=$CALICO_VERSION"

    if [ "$?" != '0' ]; then
        rm -f $HOSTFILE_TEMP_FILE
        exit 1
    fi

    rm -f $HOSTFILE_TEMP_FILE
}

main() {
    init_vars $@
    create_inventory_file

    if [ "$CREATE_USER" = 'true' ]; then
        create_user_action
    fi

    install_kubernetes_action
    init_cluster_action

}

main $@
