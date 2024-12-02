<h1> Deploy K8 cluster on linux systems</h1>

<h2>Overview</h2>

Running this script will initiate the downloaded ansible playbooks to deploy kubernetes on linux hosts.

<h2>Prerequisites</h2>

The following items are all prerequisites for the script to execute properly

* A UNIX system with ansible installed to execute the main bash script for the deployment
* Logon access via SSH to the target hosts for the ansible user. Your users will need to be able to become root
* Your target hosts will need internet access to download any necessary content
* Your target system distributions will need to be either of the ones listd below. This is because for specific actions that are not entirely distribution agnostic, the playbooks have not been properly developed. You will be prompted with this list whenever you exexute an action that is limited to these distros. Supported distros:
	- Oracle Linux 8
	- Oracle Linux 9
	- RedHat 8
	- RedHat 9
	- Ubuntu 22
	- Amazon Linux 2023

<h2>Usage</h2>

Clone the repository, navigate to the folder containing the script and the roles and execute the script providing the mandatory -r flag

```bash
git clone https://github.com/GiorgosKoulouris/MDs-and-pages.git
cd MDs-and-pages/rundeck/playbooks/linux_deploy_k8

# Full job
./00_linux_deploy_k8.sh -r all # This runs all jobs, leading to a functional cluster

# ====== Or you can execute the jobs one by one ======
# Bootstrap the hosts only
./00_linux_deploy_k8.sh -r os-bootstrap

# Create the defined user on all hosts only
./00_linux_deploy_k8.sh -r create-user

# Install kubernetes on all hosts only
./00_linux_deploy_k8.sh -r install-kube

# Initilize cluster only
./00_linux_deploy_k8.sh -r init-cluster

# ======= MISC ===========
# Create template
./00_linux_deploy_k8.sh --create-inventory-template

# Initialize the cluster without the initial user review
./00_linux_deploy_k8.sh --skip-review -r all

# Print basic help message
./00_linux_deploy_k8.sh --help
```

The -r flag is mandatory and it specifies which actions you need to deploy on the target hosts.

Valid options are:

- os-bootstrap
- create-user
- install-kube
- init-cluster
- all

<h2>Role definition</h2>

<h4>os-bootstrap</h4>

Executes some basic OS bootstraping like setting the hostname and the timezone, modifying some ssh settings. You will be prompted if you want to patch the systems as well during the execution. Before executinmg this job, review its commands to make sure it doesn't mess with configuration in ways you don't want to.

<h4>create-user</h4>

Creates a user in all of the target hosts with the purpose of administrating the cluster. Unless you manually modify the variables of the playbook, this user will have elevated access related only to kubernetes items and nothing else.

<h4>install-kube</h4>

Installs kubernetes and its dependencies based on the version you will be prompted to enter. Package locking is configured in order to avoid accidental updated of the related packages.

<h4>init-cluster</h4>

Inititializes the cluster having as a control node the host labeled as <u>controlNode1</u> and joins all of the worker nodes in the cluster. It also prompts for a user to populate the kube config to. This is helpful if you execute the playbooks one by one or if you need to execute this seperately because of an eralier failure that took place after the user creation.


<h4>all</h4>

Executes the above actions in the following sequence:

- os-bootstrap
- create-user
- install-kube
- init-cluster

<h2>Extra Options</h2>

<h4>Inventory file template</h4>

To create a template of the host inventory based on what is needed for the script to execute properly execute the following:

This will create the file <u>01-hosts-ini</u> in the script's directory. This file is the default inventory file.

```bash
# Create template
./00_linux_deploy_k8.sh --create-inventory-template
```

<h4>Skip review</h4>

Each time you execute the script, some basic user checks about the configuration of the environment and the inventory are executed. You can skip these checks by adding the <i>--skip-review</i> option **before** the <i>-r</i> flag. For example:

```bash
# Initialize the cluster without the initial user review
./00_linux_deploy_k8.sh --skip-review -r init-cluster
```

Initial checks will still be made to make sure that all the required elements are correctly set up.

<h4>Print usage and help</h4>

Print basic help by using the <i>-h</i> or <i>--help</i> flags. For example:

```bash
# Print basic help message
./00_linux_deploy_k8.sh --help
```