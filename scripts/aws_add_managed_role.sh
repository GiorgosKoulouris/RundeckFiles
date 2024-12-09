#!/bin/bash

init_vars() {
  awsAccountName="$1"
  roleName="$2"
  policyDocFile="$3"

  export VAULT_ADDR="$4"
  ROLE_ID="$5"
  SECRET_ID="$6"

  roleListFile="/rundeck/aws/roles.json"
  [ ! -f "$roleListFile" ] && echo '[]' >"$roleListFile"
}

vault_login() {
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

  echo $TOKEN | vault login - >/dev/null
}

aws_account_prechecks() {
  vault secrets list | awk -F' ' '{print $1}' | grep -Eq "^$awsAccountName/$"
  if [ $? -eq 0 ]; then
    echo "AWS account exists. Proceeding..."
  else
    echo "There is no secret engine for AWS account $awsAccountName. Exiting..."
    exit 1
  fi
}

configure_role() {
  vault list $awsAccountName/roles | grep -Eq "^$roleName$"
  if [ $? -eq 0 ]; then
    echo "Creating role..."
  else
    echo "Updating role..."
  fi

  vault write $awsAccountName/roles/$roleName \
    credential_type=iam_user \
    policy_document="$(cat $policyDocFile)" \
    policy_arns=arn:aws:iam::aws:policy/IAMUserChangePassword || exit 1

  echo "Configuring IAM Tags..."

  ttlInSeconds="$(vault read sys/mounts/$awsAccountName | grep -E "^config " |
    awk -F'[' '{print $2}' | awk -F' ' '{print $1}' | awk -F':' '{print $2}')"

  vault write $awsAccountName/roles/$roleName iam_tags="ec2c_lifespan=$ttlInSeconds"
}

update_aws_role_list() {
  # ======== Update the role list ========
  roleFullDisplayName="$awsAccountName - $roleName"

  grep -iq "$awsAccountName - $roleName" $roleListFile
  if [ $? -eq 0 ]; then
    echo "Role already exists. Skipping role list update."
  else
    echo "Updating role list..."
    jq --arg newItem "$roleFullDisplayName" '. += [$newItem]' $roleListFile >tmp.json && mv tmp.json $roleListFile
  fi
}

print_info() {
  echo "AWS role $roleName configured"
}

init_vars "$@"
vault_login
aws_account_prechecks
configure_role
update_aws_role_list
print_info
