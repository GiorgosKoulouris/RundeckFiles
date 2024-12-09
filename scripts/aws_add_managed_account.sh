#!/bin/bash

init_vars() {
  awsAccountName="$1"
  awsAccessKey="$2"
  awsSecretKey="$3"
  profileCreatorRoleArn="$4"
  leaseTTL="$5"

  export VAULT_ADDR="$6"
  ROLE_ID="$7"
  SECRET_ID="$8"

  accountListFile="/rundeck/aws/accounts.json"
  roleFullDisplayName="$awsAccountName"

  [ ! -d "/rundeck/aws" ] && mkdir -p "/rundeck/aws"
  [ ! -f "$accountListFile" ] && echo '[]' >"$accountListFile"
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

create_aws_account_entry() {
  vault secrets list | awk -F' ' '{print $1}' | grep -Eq "^$awsAccountName/$"
  if [ $? -eq 0 ]; then
    echo "AWS account with the same display name exists. Proceeding to create the role."
  else
    echo "Creating AWS secret engine..."
    vault secrets enable -path=$awsAccountName aws || exit 1
  fi

  echo "Configuring credentials..."
  vault write $awsAccountName/config/root \
    access_key="$awsAccessKey" \
    secret_key="$awsSecretKey" \
    username_template='{{ printf "EC2C-Temp-%s-%s-%s" (printf "%s" (.PolicyName) | truncate 42) (unix_time) (random 5) | truncate 64 }}' || exit 1

  vault secrets tune -default-lease-ttl=$leaseTTL -max-lease-ttl=$leaseTTL $awsAccountName/ || exit 1
}

update_account_list() {
  grep -iq "$awsAccountName" $accountListFile
  if [ $? -eq 0 ]; then
    echo "Account already exists. Skipping account list update."
  else
    echo "Updating account list..."
    jq --arg newItem "$awsAccountName" '. += [$newItem]' $accountListFile >tmp.json && mv tmp.json $accountListFile
  fi
}

update_aws_config() {
  # Update AWS CLI confuration
  awsFile="/var/lib/rundeck/.aws/config"

  # Check if the profile exists
  if grep -q "\[profile $awsAccountName\]" "$awsFile"; then
    # Profile exists, update it
    echo "Updating profile $awsAccountName..."
    # Use sed to find and replace the existing role_arn and source_profile
    sed -i.bak "/\[profile $awsAccountName\]/,/^$/ {
        s|role_arn = .*|role_arn = $profileCreatorRoleArn|;
        s|source_profile = .*|source_profile = default|;
    }" "$awsFile"
  else
    # Profile does not exist, create it
    echo "Creating profile $awsAccountName..."
    {
      echo ""
      echo "[profile $awsAccountName]"
      echo "role_arn = $profileCreatorRoleArn"
      echo "source_profile = default"
    } >>"$awsFile"
  fi
}

print_info() {
  echo "AWS account configured: $awsAccountName"
}

init_vars "$@"
vault_login
create_aws_account_entry
update_account_list
update_aws_config
print_info
