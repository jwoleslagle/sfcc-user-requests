#!/bin/bash

#######################################
# LOCAL SFCC CSR Bulk User Add script
#
# Purpose: Test and debug script used to authenticate SFCC-CI 
# and translate request entries from DynamoDB into SFCC-CI commands 
#
# Created: 3/20/2020
# Updated: 3/23/2020
# 
# Author: Jeff Woleslagle (jeffrey.woleslagle@hbc.com)
#
# TODO:
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

# ADDALL_FILE=.ADDALL_$TIMESTAMP.json #ADDALL_FILE items will be given AM and instance roles
# ADDINST_FILE=.ADDINST_$TIMESTAMP.json #ADDINST_FILE items will be given instance roles
# DELALL_FILE=.DEL_$TIMESTAMP.json #DELALL_FILE items will be removed entirely
# TIMEOUT_FILE=.TIMEOUT_$TIMESTAMP.json #TIMEOUT_FILE items will be set to TIMEOUT status (requests older than 30 days)

ADDALL_FILE="test_addAll.json" #ADDALL_FILE items will be given AM and instance roles
ADDINST_FILE="test_addInst.json" #ADDINST_FILE items will be given instance roles
DELALL_FILE="test_delAll.json" #DELALL_FILE items will be removed entirely
TIMEOUT_FILE="test_timeout.json" #TIMEOUT_FILE items will be set to TIMEOUT status (requests older than 30 days)

# This logfile will contain results from the wget attempts
#LOGFILE=wget_$TIMESTAMP.log

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
    pushCmd="curl -s -d '{\"id\": \"$1\", \"rqstStatus\": \"$2\"}\' -H \"Content-Type: application/json\" -H \"x-api-key: $API_KEY\" -X PUT $API_ENDPOINT_URL/update"
    echo $pushCmd
    pushResponse=`$pushCmd`
    echo $pushResponse
}
# Usage: pushStatusUpdatetoDDB ID NEW_STATUS

# Function to authenticate the client, this tries and exits if it returns an 'Error' rather than an 'Authorization Succeeded' message
authenticateClient () {
    auth_response=`sfcc-ci client:auth $SFCC_CI_KEY $SFCC_CI_SECRET $SFCC_CI_USER $SFCC_CI_PASS -a account.demandware.com`
    if [[ "$auth_response" != *"Authentication succeeded"* ]]; then
        echo "SFCC-CI Client Authentication was not successful - check credentials."
        exit 1
    fi
}

#######################
# First, let's set all requests older than 30 days to TIMEOUT
runTimeoutCmd () {
    #wget $TIMEOUT_URL -O $TIMEOUT_FILE -o $LOGFILE
    TIMEOUT_COUNT=`jq '.[] | .Count' $TIMEOUT_FILE`
    TIMEOUT_ARRAY=`jq '.[] | .Items' $TIMEOUT_FILE`

    if [ ${TIMEOUT_COUNT} -gt 0 ];
    then
        for i in "${TIMEOUT_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            echo "TIMEOUT (older than 30 days)- rqst id: $id"
            pushStatusUpdatetoDDB $id "TIMEOUT"
        done
    fi
}


#######################
# Second, let's delete all accounts found in /delete
runDeleteAllCmd () {
    # wget $DELALL_URL -O $DELALL_FILE -o $LOGFILE
    DEL_COUNT=`jq '.[] | .Count' $DELALL_FILE`
    DEL_ARRAY=`jq '.[] | .Items' $DELALL_FILE`

    if [ ${DEL_ARRAY[@]} -gt 0 ];
    then
        for i in "${DEL_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            email=`echo $i | jq '.[] | .email' | sed -e 's/^"//' -e 's/"$//'`
            response=`sfcc-ci user:delete -l "$email" --no-prompt`
            
            # First, make sure our auth hasn't expired and, if so, retry after reauth.
            if [[ "$response" == *"Authentication invalid"* ]]; then
                $(authenticateClient)
                # retry after re-authentication
                response=`sfcc-ci user:delete -l "$email" --no-prompt`
            fi

            if [[ "$response" == *"succeeded"* ]]; then
                echo `User $email deleted with rqst id: $id.`
                addToStatusUpdates $id "COMPLETED"
            else
                echo `User $email deleted with rqst id: $id.`
                addToStatusUpdates $id "COMPLETED"
                echo `ERROR when deleting user $email with rqst id: $id.`
                addToStatusUpdates $id "ERROR"
            fi
        done
    fi
}

# #######################
# # Third, add all accounts and account manager roles found in /add/all
runAddAllCmd () {
    # wget $ADDALL_URL -O $ADDALL_FILE -o $LOGFILE
    ADDALL_COUNT=`jq '.[] | .Count' $ADDALL_FILE`
    ADDALL_ARRAY=`jq '.[] | .Items' $ADDALL_FILE`

    if [ ${ADDALL_COUNT} -gt 0 ];
    then
        for i in "${ADDALL_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            firstName=`echo $i | jq '.[] | .firstName' | sed -e 's/^"//' -e 's/"$//'`
            lastName=`echo $i | jq '.[] | .lastName' | sed -e 's/^"//' -e 's/"$//'`
            AMRole=`echo $i | jq '.[] | .AMRole' | sed -e 's/^"//' -e 's/"$//'`
            email=`echo $i | jq '.[] | .email' | sed -e 's/^"//' -e 's/"$//'`
            # Add user to AM
            respAddUser=`sfcc-ci user:create -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -u \'{"firstName":"$firstName", "lastName":"$lastName", "roles": ["$AMRole"]}\'`
            
            # First, make sure our auth hasn't expired and, if so, retry after reauth.
            if [[ "$respAddUser" == *"Authentication invalid"* ]]; then
                $(authenticateClient)
                # retry after re-authentication
                respAddUser=`sfcc-ci user:create -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -u \'{"firstName":"$firstName", "lastName":"$lastName", "roles": ["$AMRole"]}\'`
            fi

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
}


# #######################
# # Finally, add all instance roles found in /add/inst
runAddInstCmd () {
    # wget $ADDINST_URL -O $ADDINST_FILE -o $LOGFILE
    ADDINST_COUNT=`jq '.[] | .Count' $ADDINST_FILE`
    ADDINST_ARRAY=`jq '.[] | .Items' $ADDINST_FILE`

    if [${ADDINST_ARRAY[@]} > 0];
    then
        for i in "${ADDINST_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            firstName=`echo $i | jq '.[] | .firstName' | sed -e 's/^"//' -e 's/"$//'`
            lastName=`echo $i | jq '.[] | .lastName' | sed -e 's/^"//' -e 's/"$//'`
            instRole=`echo $i | jq '.[] | .role' | sed -e 's/^"//' -e 's/"$//'`
            email=`echo $i | jq '.[] | .email' | sed -e 's/^"//' -e 's/"$//'`

            response=`sfcc-ci user:create -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -u \'{"firstName":"$firstName", "lastName":"$lastName", "roles": ["$role"]}\'`
            if [[ "$response" == *"succeeded"* ]]; then
                echo `AM role $role added to $email with rqst id: $id.`
                addToStatusUpdates $id "COMPLETED"
            elif [[ "$response" == *"No user with login"* ]]; then
                echo `Instance role "$role" could not be assigned, no login found.`
            else
                echo `ERROR when adding AM role $role to $email with id: $id.`
                addToStatusUpdates $id "ERROR"
            fi
        done
    fi
}

#######################
# EXECUTION STARTS HERE
#######################

# The following runs the above functions in order.

# Sequence is important for deletes - IAM team has been told that to revoke instance roles, they should DELALL then re-add. So, deletes are always processed first.

#runTimeoutCmd
#runDeleteAllCmd 
runAddAllCmd
#runAddInstCmd