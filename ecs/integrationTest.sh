#!/bin/bash

sm_json=`aws secretsmanager get-secret-value --secret-id prod/sfcc-requests --version-stage AWSCURRENT | jq -rc .SecretString`

getSMVariable () {
    echo $sm_json | jq .$1 | sed -e 's/^"//' -e 's/"$//'
}

SFCC_CI_KEY=`getSMVariable "SFCC_CI_KEY"`
SFCC_CI_SECRET=`getSMVariable "SFCC_CI_SECRET"`
SFCC_CI_USER=`getSMVariable "SFCC_CI_USER"`
SFCC_CI_PASS=`getSMVariable "SFCC_CI_PASS"`
API_ENDPOINT_URL=`getSMVariable "API_ENDPOINT_URL"`
API_KEY=`getSMVariable "API_KEY"`

secretsMgrTest () {
    sm_response=`aws secretsmanager get-secret-value --secret-id prod/sfcc-requests --version-stage AWSCURRENT | jq -rc .SecretString | jq .ping | sed -e 's/^"//' -e 's/"$//'`
    if [[ $sm_response == *"pong"* ]]; then
        echo "OK"
    else
        echo "FAIL"
        echo $sm_response
    fi
}

apiConnection () {
    api_response=`curl -s -H "Content-Type: application/json" -H "x-api-key: $API_KEY" -X GET $API_ENDPOINT_URL/ping | jq .message | sed -e 's/^"//' -e 's/"$//'`
    if [[ $api_response == *"Pong"* ]]; then
        echo "OK"
    else
        echo "FAIL"
        echo $api_response
    fi
}

sfccCIAuth () {
    auth_response=`sfcc-ci client:auth $SFCC_CI_KEY $SFCC_CI_SECRET $SFCC_CI_USER $SFCC_CI_PASS -a account.demandware.com`
    if [[ $auth_response == *"Authentication succeeded"* ]]; then
        echo "OK"
    else
        echo "FAIL"
        echo $auth_response 
    fi
}

echo "Testing Secrets Manager configuration... $(secretsMgrTest)"
echo "Testing API connection... $(apiConnection)"
echo "Testing SFCC-CI Authentication... $(sfccCIAuth)"