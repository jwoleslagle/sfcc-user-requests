#!/bin/sh

ADDFILE=.ADD_`date --iso-8601=seconds`.json
DELFILE=.DEL_`date --iso-8601=seconds`.json
# date +"%Y%m%d"

LOGFILE=wget.log

# wget download url
ADDURL=https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/rqsts/add
DELURL=https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/rqsts/delete

wget $ADDURL -O $ADDFILE -o $LOGFILE
toAddObj=$(<$ADDFILE)

wget $DELURL -O $DELFILE -o $LOGFILE
toDeleteObj=$(<$DELFILE)

ADD_COUNT=`jq '.[] | .Count' $ADDFILE`
DELETE_COUNT=`jq '.[] | .Count' $DELFILE`

ADD_ARRAY=`jq '.[] | .Items' $ADDFILE`
DEL_ARRAY=`jq '.[] | .Items' $DELFILE`

#Authorize the client
`sfcc-ci client:auth 9ea5c0b3-3dad-4338-a762-c7d760ec7d88 hbc2020!`

# for i in "${arrayName[@]}"
# do
#   : 
#   # do whatever on $i
# done

# print_something () {
#     echo Hello $1
# }
# print_something Mars
# print_something Jupiter