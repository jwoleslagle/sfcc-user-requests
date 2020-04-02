#!/bin/bash

#######################################
# LOCAL SFCC CSR Bulk User Add script
#
# Purpose: Test and debug script used to authenticate SFCC-CI 
# and translate request entries from DynamoDB into SFCC-CI commands 
#
# Created: 3/20/2020
# Updated: 4/1/2020
# 
# Author: Jeff Woleslagle (jeffrey.woleslagle@hbc.com)
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
ADDALL_URL="$API_ENDPOINT_URL/list/add_all"
ADDINST_URL="$API_ENDPOINT_URL/list/add_inst"
DELALL_URL="$API_ENDPOINT_URL/list/del_all"
TOTIMEOUT_URL="$API_ENDPOINT_URL/list/created?daysAgo=30"
TOSTALE_URL="$API_ENDPOINT_URL/list/updated?daysAgo=7"
STALE_URL="$API_ENDPOINT_URL/list/stale"   #stale requests have ADD_INST status for more than 7 days - reset to ADD_ALL
TIMEOUT_URL="$API_ENDPOINT_URL/list/timeout" #timeout requests are given TIMEOUT status
UPDATE_URL="$API_ENDPOINT_URL/update"

# POSSIBLE STATUSES FROM DYNAMODB TABLE
# `ADD_ALL` - Account Manager user will be added. If user exists, AM and Inst roles will be added.
# `ADD_AMROLE`- Account Manager Role will be added. If role exists, ignore and set to ADD_INST.
# `ADD_INST` - Instance Role(s) for the user will be added. If exists, ignore and set to COMPLETED.
# `DEL_ALL` - User will be removed from Account Manager and all Instance Roles will be removed.
# `ERROR` - An error was encountered. No further processing will occur.
# `STALE` - An ADD_INST request that is over 7 days old and must be deleted and returned to ADD_ALL status. SFCC invites are only good for 7 days.
# `COMPLETED` - User has been added to AM and given all roles. No further processing will occur.
# `TIMEOUT` - Requests older than 30 days are set to TIMEOUT status. No further processing will occur.

#Function to curl a status update with the PUT method, note this must happen one at a time and that ONLY status is updateable.
# Usage: $(pushStatusUpdatetoDDB) ID NEW_STATUS
pushStatusUpdatetoDDB () {
    pushCmd="curl -s -d '{\"id\": \"$1\", \"rqstStatus\": \"$2\"}\' -H \"Content-Type: application/json\" -H \"x-api-key: $API_KEY\" -X PUT $API_ENDPOINT_URL/update"
    echo $pushCmd
    pushResponse=`$pushCmd`
    echo $pushResponse
}

# Function to delete users - this action was split into a function because it's used by the commands used on multiple statuses (DEL_ALL, STALE, and TIMEOUT).
# Usage: $(deleteAll) EMAIL ID NEW_STATUS
deleteAll () { 
    response=`sfcc-ci user:delete -l "$1" --no-prompt`   
    # First, make sure our auth hasn't expired and, if so, retry after reauth.
    if [[ "$response" == *"Authentication invalid"* ]]; then
        $(authenticateClient)
        # retry after re-authentication
        response=`sfcc-ci user:delete -l "$1" --no-prompt`
    fi

    if [[ "$response" == *"succeeded"* ]]; then
        echo `User $1 deleted with rqst id: $2 . Changing status to $3 .`
        addToStatusUpdates $2 $3
    else
        echo `ERROR when deleting user $1 with rqst id: $2.`
        addToStatusUpdates $2 "ERROR"
    fi
}

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
    #wget $TOTIMEOUT_URL -O $TIMEOUT_FILE -o $LOGFILE
    TOTIMEOUT_COUNT=`jq '.[] | .Count' $TOTIMEOUT_FILE`
    TOTIMEOUT_ARRAY=`jq '.[] | .Items' $TOTIMEOUT_FILE`

    if [ ${TOTIMEOUT_COUNT} -gt 0 ];
    then
        for i in "${TOTIMEOUT_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            echo "TIMEOUT (created 30+ days ago)- rqst id: $id"
            newStatus="TIMEOUT"
            $(deleteAll) $email $id $newStatus
        done
    fi
}

#######################
# Second, let's set all requests older than 7 days to STALE, then delete the account and set the request status to ADD_ALL. Stale status needs a reset since requests older than 7 days require a new authorization email from SFCC.
runStaleCmd () {
    #wget $TOSTALE_URL -O $TIMEOUT_FILE -o $LOGFILE
    TOSTALE_COUNT=`jq '.[] | .Count' $TOSTALE_FILE`
    TOSTALE_ARRAY=`jq '.[] | .Items' $TOSTALE_FILE`

    if [ ${TOSTALE_COUNT} -gt 0 ];
    then
        for i in "${TOSTALE_ARRAY[@]}"
        do
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            email=`echo $i | jq '.[] | .email' | sed -e 's/^"//' -e 's/"$//'`
            echo "STALE (updated 7+ days ago)- rqst id: $id"
            pushStatusUpdatetoDDB $id "STALE"
            newStatus="ADD_ALL"
            $(deleteAll) $email $id $newStatus
        done
    fi
}

#######################
# Third, let's delete all accounts found in /delete
runDeleteAllCmd () {
    # wget $DELALL_URL -O $DELALL_FILE -o $LOGFILE
    DEL_COUNT=`jq '.[] | .Count' $DELALL_FILE`
    DEL_ARRAY=`jq '.[] | .Items' $DELALL_FILE`

    if [ ${DEL_ARRAY[@]} -gt 0 ];
    then
        for i in "${DEL_ARRAY[@]}"
        do
            email=`echo $i | jq '.[] | .email' | sed -e 's/^"//' -e 's/"$//'`
            id=`echo $i | jq '.[] | .id' | sed -e 's/^"//' -e 's/"$//'`
            newStatus="COMPLETED"
            $(deleteAll) $email $id $newStatus
        done
    fi
}


# #######################
# # Fifth, add all accounts and account manager roles found in /add/all
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
#runStaleCmd
#runDeleteAllCmd 
runAddAllCmd
#runAddInstCmd