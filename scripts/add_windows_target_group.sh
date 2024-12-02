#!/bin/bash

if [ $# != 3 ]; then
    echo "Wrong number of arguments. Exiting..."
    exit 1
fi

targetGroup="$1"
username="$2"
credData="$3"
osType="windows"

credentialDir="/rundeck/credentials"
credentialListFilename=01_credential_list.txt
credentialListFileFullPath="$credentialDir/$credentialListFilename"
groupListJsonFile="$credentialDir/02_group_list.json"

grep -Eq "^$targetGroup $osType" "$credentialListFileFullPath"
if [ $? = 0 ]; then
    echo "This entry already exists. Exiting."
    exit 1
fi

newCredFileName="$targetGroup.$osType.password"
newCredFileNameFullPath="$credentialDir/$newCredFileName"
if [ -f $newCredFileNameFullPath ]; then
    echo "There is credential data that is possibly related to this group. Investigate."
    exit 1
else
    echo "$credData" > $newCredFileNameFullPath
    chmod 600 $newCredFileNameFullPath
    echo "Credential file created"

    echo "$targetGroup $osType $username $newCredFileName" >> $credentialListFileFullPath
    echo "Credential entry created."
fi

groups="$(cat $credentialListFileFullPath  | grep -Ev "^#" | awk -F' ' '{print $1}' | sort | uniq)"

json_array="["

while IFS= read -r line; do
    # Add the line to the JSON array, escaping double quotes
    json_array+="\"$(echo "$line" | sed 's/"/\\"/g')\","
done <<< "$groups"

# Remove the last comma and close the JSON array
json_array="${json_array%,}]"

echo "$json_array" > "$groupListJsonFile"
