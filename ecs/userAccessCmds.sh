#!/bin/sh
# a shell script used to download a specific url.
DIR=/cygdrive/c/Al/Reports

# wget output file
FILE=.`date +"%Y%m%d"`
# date --iso-8601=seconds

# wget log file
LOGFILE=wget.log

# wget download url
URL=http://foo.com/myurl.html

cd $DIR
wget $URL -O $FILE -o $LOGFILE

