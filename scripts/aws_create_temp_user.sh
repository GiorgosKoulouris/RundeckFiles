#!/bin/bash

init_vars() {
  ROLE_NAME="$1"
  AWS_ACCOUNT="$(echo $ROLE_NAME | awk -F' - ' '{print $1}')"
  AWS_ROLE="$(echo $ROLE_NAME | awk -F' - ' '{print $2}')"

  EMAIL="$2"
  CREATE_PROFILE="$3"
  export VAULT_ADDR="$4"
  ROLE_ID="$5"
  SECRET_ID="$6"
}

check_ses_subscription() {
  # Check if user has subscribed
  aws ses list-identities | jq .Identities | grep -qi "$EMAIL"
  if [ $? -ne 0 ]; then
    echo "Email not found in the subscribed entities. Subscribe before creating an account. Exiting."
    exit 1
  else
    echo "Email has subscribed. Proceeding."
  fi
}

vault_login() {
  # Hashicorp Vault Values
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
}

create_user() {
  # Get credentials for the new AWS user
  AWS_CREDS="$(curl -s -X GET \
    -H "X-Vault-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    $VAULT_ADDR/v1/$AWS_ACCOUNT/creds/$AWS_ROLE)"

  sleep 7

  echo $AWS_CREDS | grep -iq access_key
  if [ $? -ne 0 ]; then
    echo "Could not retrieve AWS credentials. Exiting."
    exit 1
  else
    echo "AWS credentials retrieved..."
  fi

  RSLT_AWS_KEY="$(echo $AWS_CREDS | jq .data.access_key | sed 's/"//g')"
  RSLT_AWS_SECRET="$(echo $AWS_CREDS | jq .data.secret_key | sed 's/"//g')"

  AWS_IDENTITY="$(AWS_ACCESS_KEY_ID=$RSLT_AWS_KEY AWS_SECRET_ACCESS_KEY=$RSLT_AWS_SECRET aws sts get-caller-identity)"
  RSLT_ACCOUNT_ID="$(echo $AWS_IDENTITY | jq '.Account' | sed 's/"//g')"
  RSLT_USERNAME="$(echo $AWS_IDENTITY | jq '.Arn' | awk -F'/' '{print $2}' | sed 's/"//g')"

  if [ "$CREATE_PROFILE" = 'true' ]; then
    echo "Creating login profile..."
    RSLT_TEMP_PASS="$(tr </dev/urandom -dc 'A-Za-z0-9' | head -c 22)"
    aws iam create-login-profile --profile "$AWS_ACCOUNT" --user-name "$RSLT_USERNAME" --password "$RSLT_TEMP_PASS" --password-reset-required >/dev/null
    if [ $? -ne 0 ]; then
      echo "Could not create login profile. Access key will be delivered."
      emailBody="$(printf "Account ID: %s\nUsername: %s\nAccess Key: %s\nSecret Key: %s\n" \
        $RSLT_ACCOUNT_ID $RSLT_USERNAME $RSLT_AWS_KEY $RSLT_AWS_SECRET)"
    else
      emailBody="$(printf "Account ID: %s\nUsername: %s\nConsole Password: %s\nAccess Key: %s\nSecret Key: %s\n" \
        $RSLT_ACCOUNT_ID $RSLT_USERNAME $RSLT_TEMP_PASS $RSLT_AWS_KEY $RSLT_AWS_SECRET)"
    fi
  else
    echo "Login profile will not be created."
    emailBody="$(printf "Account ID: %s\nUsername: %s\nAccess Key: %s\nSecret Key: %s\n" \
      $RSLT_ACCOUNT_ID $RSLT_USERNAME $RSLT_AWS_KEY $RSLT_AWS_SECRET)"
  fi
}

send_ses_email() {
  aws ses send-email \
    --from "rundeck-notifications@thecanopener.com" \
    --destination "ToAddresses=[$EMAIL]" \
    --message "Subject={Data='Rundeck Jobs: Temporary AWS credentials for $AWS_ACCOUNT'},Body={Text={Data='$emailBody'}}" >/dev/null

  if [ $? -eq 0 ]; then
    echo "Job succeded. Check your email for the credentials."
  else
    echo "There was an error delivering the credentials. Exiting."
    exit 1
  fi
}

init_vars "$@"
check_ses_subscription
vault_login
create_user
send_ses_email

