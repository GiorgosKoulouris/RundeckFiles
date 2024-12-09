#!/bin/bash

if [ $# != 1 ]; then
    echo "Wrong number of arguments. Exiting..."
    exit 1
fi

targetGroup="$1"

credentialDir="/rundeck/credentials"
credentialListFilename=01_credential_list.txt
credentialListFileFullPath="$credentialDir/$credentialListFilename"
groupListJsonFile="$credentialDir/02_group_list.json"

[ ! -f "$groupListJsonFile" ] && echo "[]" > "$groupListJsonFile"

filesToDelete="$(grep -E "^$targetGroup " "$credentialListFileFullPath" | awk -F' ' '{print $NF}')"

while IFS= read -r line; do
    rm -f "$credentialDir/$line" && echo "Removed: $credentialDir/$line"
done <<< "$filesToDelete"

cat $credentialListFileFullPath | grep -Ev "^$targetGroup " > "$credentialDir/list.tmp" && \
    rm -f "$credentialListFileFullPath" && \
    mv "$credentialDir/list.tmp" "$credentialListFileFullPath" && \
    echo "Updated credential list"

if [ $? != 0 ]; then
    echo "Failed to update the credential list. Exiting."
    exit 1
fi

groups="$(cat $credentialListFileFullPath  | grep -Ev "^#" | awk -F' ' '{print $1}' | sort | uniq)"

json_array="["

while IFS= read -r line; do
    # Add the line to the JSON array, escaping double quotes
    json_array+="\"$(echo "$line" | sed 's/"/\\"/g')\","
done <<< "$groups"

# Remove the last comma and close the JSON array
json_array="${json_array%,}]"

echo "$json_array" > "$groupListJsonFile" && echo "Updated group list"
