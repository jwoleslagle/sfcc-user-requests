#!/bin/sh

#Global variables
SFCC_CI_KEY='9ea5c0b3-3dad-4338-a762-c7d760ec7d88'
SFCC_CI_PASS='hbc2020!'
API_ENDPOINT_URL='https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/rqsts'
TIMESTAMP=`date --iso-8601=seconds`

#ADDFILE items will be given AM and instance roles, DELFILE items will be removed entirely, and PUTFILE will contain status updates for items that changed  
ADDALL_FILE=.ADDALL_$TIMESTAMP.json
ADDINST_FILE=.ADDINST_$TIMESTAMP.json
DELALL_FILE=.DEL_$TIMESTAMP.json
UPDATE_FILE=.PUT_$TIMESTAMP.json
# date +"%Y%m%d"

# This logfile will contain results from the wget attempts
LOGFILE=wget_$TIMESTAMP.log

# wget download urls
ADDALL_URL=$API_ENDPOINT_URL/add/all
ADDINST_URL=$API_ENDPOINT_URL/add/inst
DELALL_URL=$API_ENDPOINT_URL/delete
UPDATE_URL=$API_ENDPOINT_URL/update

# get ADDs and DELETEs and #backfill into a variable
wget $ADDALL_URL -O $ADDALL_FILE -o $LOGFILE
#toAddObj=$(<$ADDALL_FILE)

wget $DELALL_URL -O $DELALL_FILE -o $LOGFILE
#toDeleteObj=$(<$DELALL_FILE)

wget $ADDINST_URL -O $ADDINST_FILE -o $LOGFILE
#toDeleteObj=$(<$ADDINST_FILE)

# get starting counts and arrays of items to ADD and DELETE
ADD_COUNT=`jq '.[] | .Count' $ADDFILE`
ADD_ARRAY=`jq '.[] | .Items' $ADDFILE`

DELETE_COUNT=`jq '.[] | .Count' $DELFILE`
DEL_ARRAY=`jq '.[] | .Items' $DELFILE`

#Authorize the client, this tries and exit(1) if it returns an 'Error' rather than an 'Authorization Succeeded' message
auth_response=`sfcc-ci client:auth $SFCC_CI_KEY $SFCC_CI_PASS`
if [[ "$auth_response" != *"Authorization Suceeded"* ]]; then
    echo "SFCC-CI Client Authorization was not successful - check credentials."
    exit 1
fi

#Function to create a status update and append to PUT file: id is $1, new status is $2, TODO create function
# addToStatusUpdates () {
#     echo Hello $1
# }
# addToStatusUpdates ID NEW_STATUS

#Function to curl a status update with the PUT method, note this must happen one at a time and that only status is updateable: id is $1, new status is $2, TODO create function
pushStatusUpdatetoDDB () {
    `curl -d \'{"id": $1, "rqstStatus": $2}\' -H "Content-Type: application/json" -X POST $API_ENDPOINT_URL/update`

}
# pushStatusUpdatetoDDB ID NEW_STATUS

#Function to run an sfcc-ci command for a certain status: id is $1, TODO: map all variables, create function
# runSFCC_CICommand () {
#     echo Hello $1
# }
# runSFCC_CICommand ID NEW_STATUS


# for i in "${arrayName[@]}"
# do
#   : 
#   # do whatever on $i
# done

# Template for user actions
# sfcc-ci user:create -o "Saks & Company LLC and its affiliates" -l "joe.shmoe@hbc.com" -u '{"firstName":"Joe", "lastName":"Shmoe", "roles": ["bm-user"]}'
# sfcc-ci user:delete --login "joe.shmoe@hbc.com" --no-prompt 

# Template for AM Role Grant
# sfcc-ci role:grant -l "joe.shmoe@hbc.com" -r "bm-user" -s "bdms_prd"

# Template for Instance role grant
# sfcc-ci role:grant -i production-na01-hbc.demandware.net -l "joe.shmoe@hbc.com" -r "call-center"