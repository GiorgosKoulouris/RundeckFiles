<h1>Promote Windows servers to Domain Controllers</h1>

<h2>Overview</h2>

Running this script will initiate the downloaded ansible playbook to promote one or more Windows Servers to Domain Controllers

<h2>Prerequisites</h2>

The following items are all prerequisites for the script to execute properly

* A UNIX system with ansible installed to execute the main bash script for the deployment
* Credentials for a local administrator of the target system
* Your target hosts will need internet access to download any necessary content
* Has been tested on the following:
	- Windows Server 2016
	- Windows Server 2019
	- Windows Server 2022

<h2>Usage</h2>

Clone the repository and navigate to the folder containing the script and the roles. Edit the CSV with all the necessary info. You don't need any inventory or variable file, these are generated dynamically during runtime based on the CSV file.

<b>Note:</b> When executing the script in list mode, <u>you cannot have 2 target hosts with the same hostname</u>, as it generates unexpected results.

```bash
git clone https://github.com/GiorgosKoulouris/MDs-and-pages.git
cd MDs-and-pages/ansible-playbooks/win_promote_to_dc

# Example 1: Promote a single server
./00_win_promote_to_dc

# Example 2: Promote multiple servers
./00_win_promote_to_dc --create-csv-template # To create the template CSV
vi 01-hostInfo.csv # To edit. Do not remove the trailing commas on each row, there is an empty collumb in the end
./00_win_promote_to_dc --list-mode # Run the job

# Example 3: Promote multiple servers using a custom list
./00_win_promote_to_dc --list-mode -l /path/to/list # The list should be formatted exactly as the template

# Example 4: Cleanup all files containing sensitive information
./00_win_promote_to_dc --cleanup
```


<h2>Connectivity</h2>

You will need to make sure that traffic is allowed on OS level. Check the OS firewall settings for deny rules on ports 5985 and 5986.

Make sure that Authentication settings on target OS and winRM settings are set correctly. If they are not, you will receive authentication errors when executing the playbook.

```powershell
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Set-NetFirewallProfile -Profile domain,public,private -Enabled False
```

<h2>OBJC related errors</h2>

If you receive any OBJC related errors during the job execution, run the following and try to run the job again:

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```
