#!/bin/bash

targetGroup="$1"
osType="$2"

if [ $# != 2 ]; then
    echo "Wrong number of arguments. Exiting..."
    exit 1
fi

credentialDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
credentialListFilename=01_credential_list.txt
credentialFileFullPath="$credentialDir/$credentialListFilename"

[ ! -f "$credentialFileFullPath" ] && touch "$credentialFileFullPath"

values="$(grep -E "^$targetGroup $osType" "$credentialFileFullPath")"

if [ $? != 0 ]; then
    echo "No credential configuration found for group $targetGroup. Exiting."
    exit 1
else
    lineCount=$(echo $values | wc -l | awk -F' ' '{print $1}')
    if [ $lineCount != 1 ]; then
        echo "Credential config: Multiple lines found for group $targetGroup. Exiting."
        exit 1
    fi
fi

if [ "$osType" = 'linux' ]; then
    authType="$(echo $values | awk -F' ' '{print $3}')"
    username="$(echo $values | awk -F' ' '{print $4}')"
    file="$(echo $values | awk -F' ' '{print $5}')"
    echo $authType $username "$credentialDir/$file"
elif [ "$osType" = 'windows' ]; then
    username="$(echo $values | awk -F' ' '{print $3}')"
    file="$(echo $values | awk -F' ' '{print $4}')"
    echo $username "$credentialDir/$file"
fi
