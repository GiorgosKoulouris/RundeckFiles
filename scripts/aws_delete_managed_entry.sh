#!/bin/bash

init_vars() {
  deletionType="$1"

  awsAccountName="$2"
  awsFullName="$3"

  export VAULT_ADDR="$4"
  ROLE_ID="$5"
  SECRET_ID="$6"

  accountListFile="/rundeck/aws/accounts.json"
  roleListFile="/rundeck/aws/roles.json"
  awsConfigFile="/var/lib/rundeck/.aws/config"
}

vault_login(){
  TOKEN="$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{ \"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\" }" \
    $VAULT_ADDR/v1/auth/approle/login |
    jq -r '.auth.client_token')"

  if [[ ${#TOKEN} -lt 6 ]]; then
    echo "Vault token could not be retrieved. Exiting."
    exit 1
  else
    echo "Vault token retrieved..."
  fi

  echo $TOKEN | vault login - > /dev/null
}

delete_account() {
  if [ "$awsAccountName" = '' ]; then
    echo "AWS account cannot be empty. Exiting..."
    exit 1
  fi

  echo "Deleting AWS account $awsAccountName"
  vault secrets disable $awsAccountName || exit 1

  echo "Updating rundeck AWS account list..."
  jq --arg var "$awsAccountName" 'map(select(. != $var))' $accountListFile > tmp.json && mv tmp.json $accountListFile

  echo "Updating rundeck AWS role list..."
  jq --arg var "$awsAccountName" 'map(select(. | contains($var + " - ") | not))' $roleListFile > tmp.json && mv tmp.json $roleListFile

  echo "Updating rundeck AWS cli configuration..."
  awk -v profile="profile $awsAccountName" '
    $0 ~ "\\[profile" {
        in_profile = ($0 == "[" profile "]")
    }
    !in_profile
' "$awsConfigFile" > temp_file && mv temp_file "$awsConfigFile"
}

delete_role() {
  if [ "$awsFullName" = '' ]; then
    echo "Role cannot be empty. Exiting..."
    exit 1
  fi

  echo "Deleting role $roleDisplayName"

  awsAccountName="$(echo $awsFullName | awk -F' - ' '{print $1}')"
  awsRoleName="$(echo $awsFullName | awk -F' - ' '{print $2}')"
  vault delete $awsAccountName/roles/$awsRoleName || exit 1

  echo "Updating rundeck AWS role list..."
  jq --arg var "$awsFullName" 'map(select(. != $var))' $roleListFile > tmp.json && mv tmp.json $roleListFile
}


init_vars "$@"
vault_login

if [ "$deletionType" = 'Account' ]; then
  delete_account
elif [ "$deletionType" = 'Role' ]; then
  delete_role
fi
