#!/bin/bash

#######################################
# SFCC CSR Bulk User Add script
#
# Purpose: Authenticate SFCC-CI and translate 
# request entries from DynamoDB into SFCC-CI commands 
#
# Created: 3/20/2020
# Updated: 3/23/2020
# 
# Author: Jeff Woleslagle (jeffrey.woleslagle@hbc.com)
#
# TODO:
# - Pass user to user
# - Add secrets manager support
# - Test extensively
#
#######################################

#Set global variables from those stored in AWS Secrets Manager

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

# These three functions test to make sure we can connect to all required components, and exit 1 if not.
secretsMgrTest () {
    sm_response=`aws secretsmanager get-secret-value --secret-id prod/sfcc-requests --version-stage AWSCURRENT | jq -rc .SecretString | jq .ping | sed -e 's/^"//' -e 's/"$//'`
    if [[ $sm_response == *"pong"* ]]; then
        sm_response_status="OK"
        echo $sm_response_status
    else
        sm_response_status="FAIL"
        echo $sm_response_status
        echo $sm_response
    fi
}

apiConnection () {
    api_response=`curl -s -H "Content-Type: application/json" -H "x-api-key: $API_KEY" -X GET $API_ENDPOINT_URL/ping | jq .message | sed -e 's/^"//' -e 's/"$//'`
    if [[ $api_response == *"Pong"* ]]; then
        api_response_status="OK"
        echo $api_response_status
    else
        api_response_status="FAIL"
        echo $api_response_status
        echo $api_response
    fi
}

sfccCIAuth () {
    auth_response=`sfcc-ci client:auth $SFCC_CI_KEY $SFCC_CI_SECRET $SFCC_CI_USER $SFCC_CI_PASS -a account.demandware.com`
    if [[ $auth_response == *"Authentication succeeded"* ]]; then
        auth_response_status="OK"
        echo $auth_response_status
    else
        auth_response_status="FAIL"
        echo $auth_response_status
        echo $auth_response 
    fi
}

## Test all critical connections - exit if unable to connect

echo "Testing Secrets Manager configuration... "
sm_result="$(secretsMgrTest)"
echo $sm_result

echo "Testing API connection... "
api_result="$(apiConnection)"
echo $api_result

echo "Testing SFCC-CI Authentication... "
sfcc_result="$(sfccCIAuth)"
echo $sfcc_result

if [[ $sm_result == "OK" ]] && [[ $api_result == "OK" ]] && [[ $sfcc_result == "OK" ]];
then
    echo "All critical processes connected OK. Continuing..."
else
    echo "One or more critical processes failed to connect. Exiting..."
    exit 1
fi

#Initially used ISO-8601, but this format has colons(:) and can't be used in file names
TIMESTAMP=`date +%h%d%Y"UTC"%H%M%S -u`

ADDALL_FILE=.ADDALL_$TIMESTAMP.json #ADDALL_FILE items will be given AM and instance roles
ADDINST_FILE=.ADDINST_$TIMESTAMP.json #ADDINST_FILE items will be given instance roles
DELALL_FILE=.DEL_$TIMESTAMP.json #DELALL_FILE items will be removed entirely
TIMEOUT_FILE=.TIMEOUT_$TIMESTAMP.json #TIMEOUT_FILE items will be set to TIMEOUT status (requests older than 30 days)

# This logfile will contain results from the wget attempts
LOGFILE=wget_$TIMESTAMP.log

# wget download urls
ADDALL_URL=$API_ENDPOINT_URL/add/all
ADDINST_URL=$API_ENDPOINT_URL/add/inst
DELALL_URL=$API_ENDPOINT_URL/delete
UPDATE_URL=$API_ENDPOINT_URL/update
TIMEOUT_URL=$API_ENDPOINT_URL/timeout

# POSSIBLE STATUSES FROM DYNAMODB TABLE
# `ADD_ALL` - Account Manager user will be added. If user exists, AM and Inst roles will be added.
# `ADD_AMROLE`- Account Manager Role will be added. If role exists, ignore and set to ADD_INST.
# `ADD_INST` - Instance Role(s) for the user will be added. If exists, ignore and set to COMPLETED.
# `DEL_ALL` - User will be removed from Account Manager and all Instance Roles will be removed.
# `ERROR` - An error was encountered. No further processing will occur.
# `COMPLETED` - User has been added to AM and given all roles. No further processing will occur.
# `TIMEOUT` - Requests older than 30 days are set to TIMEOUT status. No further processing will occur.

#Function to curl a status update with the PUT method, note this must happen one at a time and that ONLY status is updateable: id is $1, new status is $2
pushStatusUpdatetoDDB () {
    `curl -d \'{"id": $1, "rqstStatus": $2}\' -H "Content-Type: application/json" \'x-api-key: $API_KEY \' -X PUT $API_ENDPOINT_URL/update`
}
# Usage: pushStatusUpdatetoDDB ID NEW_STATUS

# Function to authenticate the client, this tries and exits if it returns an 'Error' rather than an 'Authorization Succeeded' message
authenticateClient () {
    auth_response=`sfcc-ci client:auth $SFCC_CI_KEY $SFCC_CI_SECRET $SFCC_CI_USER $SFCC_CI_PASS -a account.demandware.com`
    if [[ "$auth_response" != *"Authorization Succeeded"* ]]; then
        echo "SFCC-CI Client Authorization was not successful - check credentials."
        exit 1
    fi
}

#######################
# EXECUTION STARTS HERE
#######################

#######################
# First, let's set all requests older than 30 days to TIMEOUT
wget $TIMEOUT_URL -O $TIMEOUT_FILE -o $LOGFILE
TIMEOUT_COUNT=`jq '.[] | .Count' $TIMEOUT_FILE`
TIMEOUT_ARRAY=`jq '.[] | .Items' $TIMEOUT_FILE`

if [ ${TIMEOUT_COUNT} -gt 0 ];
then
    for i in "${TIMEOUT_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        echo `TIMEOUT (older than 30 days)- rqst id: $id.`
        addToStatusUpdates $id "TIMEOUT"
    done
fi

#######################
# Next, let's delete all accounts found in /delete
wget $DELALL_URL -O $DELALL_FILE -o $LOGFILE
DEL_COUNT=`jq '.[] | .Count' $DELALL_FILE`
DEL_ARRAY=`jq '.[] | .Items' $DELALL_FILE`

if [ ${DEL_COUNT} -gt 0 ];
then
    for i in "${DEL_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        email=`jq '.[] | .email' $i`
        response=`sfcc-ci user:delete -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" --no-prompt`
        responseStatus=
        if [[ "$response" == *"succeeded"* ]]; then
            echo `User $email deleted with rqst id: $id.`
            addToStatusUpdates $id "COMPLETED"
        else
            echo `ERROR when deleting user $email with rqst id: $id.`
            addToStatusUpdates $id "ERROR"
        fi
    done
fi

#######################
# Next, add all accounts and account manager roles found in /add/all
wget $ADDALL_URL -O $ADDALL_FILE -o $LOGFILE
ADDALL_COUNT=`jq '.[] | .Count' $ADDALL_FILE`
ADDALL_ARRAY=`jq '.[] | .Items' $ADDALL_FILE`

# EXAMPLE JSON: {"role":"CSR","lastName":"Dodger","banner":"bdpt_prd","AMRole":"bm-user","updatedAt":"2020-03-05T18:49:51.372Z","rqstStatus":"ADD_ALL","createdAt":"2020-03-05T18:49:51.372Z","email":"roger.dodger@hbc.com","id":"18865bd0-5f12-11ea-8c4a-37f7a440c45f","firstName":"Roger"}
if [ ${ADDALL_COUNT} -gt 0 ];
then
    for i in "${ADDALL_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        firstName=`jq '.[] | .firstName' $i`
        lastName=`jq '.[] | .lastName' $i`
        AMRole=`jq '.[] | .AMRole' $i`
        email=`jq '.[] | .email' $i`
        # Add user to AM
        respAddUser=`sfcc-ci user:create -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -u \'{"firstName":"$firstName", "lastName":"$lastName", "roles": ["$AMRole"]}\'`
        if [[ "$respAddUser" == *"succeeded"* ]]; then
            echo `User $email created with rqst id: $id.`
            pushStatusUpdatetoDDB $id "ADD_INST"
        elif [[ "$respAddUser" == *"user not unique"* ]]; then
            echo `User creation with $email not completed with rqst id: $id - user already exists.`
        else
            echo `ERROR when creating user $email with id: $id.`
            pushStatusUpdatetoDDB $id "ERROR"
        fi
        # Add AM Role
        respAddAMRole=`sfcc-ci role:grant -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -r "$AMRole" -s "$banner"`
        if [[ "$respAddAMRole" == *"succeeded"* ]]; then
            echo `AM role $role added to $email with rqst id: $id.`
            pushStatusUpdatetoDDB $id "ADD_INST"
        elif [[ "$respAddUser" == *"user not unique"* ]]; then
            echo `AM role $role already assigned to $email with rqst id: $id.`
            pushStatusUpdatetoDDB $id "ADD_INST"
        else
            echo `ERROR when adding AM role $role to $email with id: $id.`
            pushStatusUpdatetoDDB $id "ERROR"
        fi
    done
fi

#######################
# Finally, add all instance roles found in /add/inst

wget $ADDINST_URL -O $ADDINST_FILE -o $LOGFILE
ADDINST_COUNT=`jq '.[] | .Count' $ADDINST_FILE`
ADDINST_ARRAY=`jq '.[] | .Items' $ADDINST_FILE`

if [ ${ADDINST_COUNT} -gt 0 ];
then
    for i in "${ADDINST_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        firstName=`jq '.[] | .firstName' $i`
        lastName=`jq '.[] | .lastName' $i`
        instRole=`jq '.[] | .AMRole' $i`
        email=`jq '.[] | .email' $i`

        response=`sfcc-ci user:create -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -u \'{"firstName":"$firstName", "lastName":"$lastName", "roles": ["$role"]}\'`
        responseStatus=
        if [[ "$response" == *"succeeded"* ]]; then
            echo `AM role $role added to $email with rqst id: $id.`
            addToStatusUpdates $id "COMPLETED"
        elif [[ "$response" == *"No user with login"* ]]; then
            echo `AM role $role already assigned to $email with rqst id: $id.`
            addToStatusUpdates $id "COMPLETED"
        else
            echo `ERROR when adding AM role $role to $email with id: $id.`
            addToStatusUpdates $id "ERROR"
        fi
    done
fi