#!/bin/bash

init_vars() {
    action="$1"
    email="$2"
}

check_prohibited() {
    if [ "$email" = 'thecanopener.com' ]; then
        echo "Cannot delete the verified domain. Be cautious..."
        exit 1
    elif [ "$email" = 'rundeck-notifications@thecanopener.com' ]; then
        echo "Cannot delete the notifications identity user. Be cautious..."
        exit 1
    fi
}

subscribe() {
    aws ses verify-email-identity --email-address "$email"
    if [ $? -eq 0 ]; then
        echo "Verify the subscription for $email. Review your emails."
    else
        echo "There was an error sending the verification email. Exiting..."
        exit 1
    fi
}

unsubscribe() {
    subscribedEntities=$(aws ses list-identities | jq .Identities | grep -vE "(^\[$|^\]$)" | sed 's/"//g' | sed 's/,//g' | sed 's/^  //g' | grep -qE "^$email$")
    if [ $? -eq 0 ]; then
        echo "Unsubscribing $email..."
        aws ses delete-identity --identity $email
    else
        echo "There is no verified subscription for $email. Exiting."
    fi
}

init_vars "$@"
check_prohibited

if [ "$action" = 'Subscribe' ]; then
    subscribe
elif [ "$action" = 'Unsubscribe' ]; then
    unsubscribe
fi

