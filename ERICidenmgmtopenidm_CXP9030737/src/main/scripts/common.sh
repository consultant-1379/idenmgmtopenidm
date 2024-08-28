#!/bin/bash

################################################################################
# Copyright (c) 2014 Ericsson, Inc. All Rights Reserved.
# This script contains the common functions used by all OpenDJ scripts
# Author: Simohamed Elmajdoubi
# ESN 38708
# 
###############################################################################


######################################################################
# This functions creates the log file
# The calling script must define the two variables: $LOG_DIR and $LOG_DIR 
# Arguments: None
#
# Returns:
#   0      Success
#   1      Failure
#
######################################################################
SetLogFile()
{

   # Create the log directory if it does not already exist 
   if [ ! -d $LOG_DIR ] ; then
      mkdir -p $LOG_DIR
      if [ $? != 0 ] ; then
         echo "Failed to create $LOG_DIR"
         exit 1
      fi
   fi
   chown openidm:openidm $LOG_DIR
   if [ $? != 0 ] ; then
      echo "Failed to set ownership on $LOG_DIR"
      exit 1
   fi

   # Construct the LOG_ FILE name and create it and validate it can be written
   touch $LOG_FILE 
   if [ $? != 0 ] ; then
      echo "Failed to create $LOG_FILE"
      exit 1
   fi

   # change permission on log file to rw to all
   chmod 666 $LOG_FILE 
   if [ $? != 0 ] ; then
      echo "Failed to set permssions on $LOG_FILE"
      exit 1
   fi

   # change owner to openidm
   chown openidm:openidm $LOG_FILE
   if [ $? != 0 ] ; then
      echo "Failed to change ownership of $LOG_FILE"
      exit 1
   fi
   
   return 0
}

######################################################################
# This functions prints messages into the log file
# Arguments: $1 the message to prin
#
######################################################################

LogMessage()
{ 
   ts=`/bin/date "+%F:%H:%M:%S%:z"`
   msg="$ts: $1"
   echo $msg 
   echo $msg >> $LOG_FILE
}

################################################################################
# Function:    checkServiceStatus
# Description: Check whether the specific service is running or not
# Parameters:  $1 (the name of the service, such as "opendj" and "openidm")
# Return:      0 (the speific service is running)
#              1 (the specific service is not running)
###############################################################################
function checkServiceStatus(){

    if [[ $1 == "sso" ]] ; then
       sso_serviceStatus=`$SSO_SCRIPT 2`

      if [[ $sso_serviceStatus -eq 0 ]] ; then
        LogMessage "INFO: $1 is running"
        return 0
      else
        LogMessage "ERROR: $1 is not running"
        return 1
      fi


    else
       serviceStatus=`service $1 status`

       if [[ "$serviceStatus" =~ "is running" ]] ; then 
         LogMessage "INFO: $1 is running"
         return 0
       else
         LogMessage "ERROR: $1 is not running"
         return 1
       fi
    fi
}



















