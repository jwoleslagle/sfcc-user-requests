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

#Global variables

#TODO REPLACE THE FOLLOWING WITH SECRETS MANAGER VARIABLES
SFCC_CI_KEY='9ea5c0b3-3dad-4338-a762-c7d760ec7d88'
SFCC_CI_SECRET='hbc2020!'
SFCC_CI_USER='hbcsfcccsr@hbc.com'
SFCC_CI_PASS='hbc2020!'
API_ENDPOINT_URL='https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/rqsts'
API_KEY='SET_THIS_API_KEY_FOR_PRODUCTION'

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
# Usage: pushStatusUpdatetoDDB() ID NEW_STATUS

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

if [${TIMEOUT_ARRAY[@]} > 0]
    for i in "${TIMEOUT_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        echo `TIMEOUT (older than 30 days)- rqst id: $id.`
        addToStatusUpdates() $id "TIMEOUT"
    done
fi

#######################
# Next, let's delete all accounts found in /delete
wget $DELALL_URL -O $DELALL_FILE -o $LOGFILE
DELETE_COUNT=`jq '.[] | .Count' $DELALL_FILE`
DEL_ARRAY=`jq '.[] | .Items' $DELALL_FILE`

if [${DELALL_ARRAY[@]} > 0]
    for i in "${DELALL_ARRAY[@]}"
    do
        id=`jq '.[] | .id' $i`
        email=`jq '.[] | .email' $i`
        response=`sfcc-ci user:delete -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" --no-prompt`
        responseStatus=
        if [[ "$response" == *"succeeded"* ]]; then
            echo `User $email deleted with rqst id: $id.`
            addToStatusUpdates() $id "COMPLETED"
        else
            echo `ERROR when deleting user $email with rqst id: $id.`
            addToStatusUpdates() $id "ERROR"
        fi
    done
fi

#######################
# Next, add all accounts and account manager roles found in /add/all
wget $ADDALL_URL -O $ADDALL_FILE -o $LOGFILE
ADDALL_COUNT=`jq '.[] | .Count' $ADDALL_FILE`
ADDALL_ARRAY=`jq '.[] | .Items' $ADDALL_FILE`

# EXAMPLE JSON: {"role":"CSR","lastName":"Dodger","banner":"bdpt_prd","AMRole":"bm-user","updatedAt":"2020-03-05T18:49:51.372Z","rqstStatus":"ADD_ALL","createdAt":"2020-03-05T18:49:51.372Z","email":"roger.dodger@hbc.com","id":"18865bd0-5f12-11ea-8c4a-37f7a440c45f","firstName":"Roger"}
if [${ADDALL_ARRAY[@]} > 0]
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
            pushStatusUpdatetoDDB() $id "ADD_INST"
        elif [[ "$respAddUser" == *"user not unique"* ]]; then
            echo `User creation with $email not completed with rqst id: $id - user already exists.`
        else
            echo `ERROR when creating user $email with id: $id.`
            pushStatusUpdatetoDDB() $id "ERROR"
        fi
        # Add AM Role
        respAddAMRole=`sfcc-ci role:grant -o "Saks & Company LLC and its affiliates - No 2FA" -l "$email" -r "$AMRole" -s "$banner"`
        if [[ "$respAddAMRole" == *"succeeded"* ]]; then
            echo `AM role $role added to $email with rqst id: $id.`
            pushStatusUpdatetoDDB() $id "ADD_INST"
        elif [[ "$respAddUser" == *"user not unique"* ]]; then
            echo `AM role $role already assigned to $email with rqst id: $id.`
            pushStatusUpdatetoDDB() $id "ADD_INST"
        else
            echo `ERROR when adding AM role $role to $email with id: $id.`
            pushStatusUpdatetoDDB() $id "ERROR"
        fi
    done
fi

#######################
# Finally, add all instance roles found in /add/inst

wget $ADDINST_URL -O $ADDINST_FILE -o $LOGFILE
ADDINST_COUNT=`jq '.[] | .Count' $ADDINST_FILE`
ADDINST_ARRAY=`jq '.[] | .Items' $ADDINST_FILE`

if [${ADDINST_ARRAY[@]} > 0]
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
            addToStatusUpdates() $id "COMPLETED"
        elif [[ "$response" == *"No user with login"* ]]; then
            echo `AM role $role already assigned to $email with rqst id: $id.`
            addToStatusUpdates() $id "COMPLETED"
        else
            echo `ERROR when adding AM role $role to $email with id: $id.`
            addToStatusUpdates() $id "ERROR"
        fi
    done
fi