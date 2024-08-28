#!/bin/bash

################################################################################
# Copyright (c) 2014 Ericsson, Inc. All Rights Reserved.
# This script is to parse application policies and create roles for application
# based on the parsed results
#
# This script will be called by torINST during installing and upgrading
# 
# Author: Ben Deng
# ESN 38137
################################################################################

# Log definition
LOG_DIR="/var/log/openidm"
DATENOW=$(/bin/date +"%Y-%m-%d-%H:%M:%z")
LOG_FILE="${LOG_DIR}/create_application_roles-${DATENOW}.log"


GREP=/bin/grep
CURL=/usr/bin/curl
SED=/bin/sed
LS=/bin/ls
WC=/usr/bin/wc
RM=/bin/rm
CAT=/bin/cat
AWK=/bin/awk
OPENSSL=/usr/bin/openssl
GETENT=/usr/bin/getent

IDENMGMT_DIR=/opt/ericsson/com.ericsson.oss.security/idenmgmt
COMMON_SCRIPT="$IDENMGMT_DIR/openidm/bin/common.sh"

SSO_SCRIPT="/opt/ericsson/sso/bin/sso-heart-beat.sh"

# Application Policy Set files
POLICYSETS="/ericsson/tor/data/access_control/policies/default/*.json"

# OpenIDM Password key
SECADMIN_PASSKEY=/ericsson/tor/data/idenmgmt/secadmin_passkey

# Parsing resulted array
declare -A APP_ROLE_ARRAY
NUM_COLUMN_IN_APP_ROLE_ARRAY=2
ROLE_INDEX=0
DESC_INDEX=1

# other global variables
POLICY_SPLITER='"Name"'
ROLE_IDENTIFIER='"Role"'
DESCRIPTION_IDENTIFIER='"Description"'

# initialize the policy count to zero
POLICY_COUNT=0

# Policy Agent and certs
COOKIE_FILE=/tmp/applicationRoleCookie.txt
SSO_CERT=/ericsson/tor/data/certificates/sso/ssoserverapache.crt

# openidm credential
SECADMIN_USER="administrator"

# settings in global.properties
GLOBAL_PROPERTY_FILE=/ericsson/tor/data/global.properties

################################################################################
# Function:    parsePolicySets
# Description: parse the application policyset files, and obtain the description
#              and the role for each individual application policy.
#
#              All the policset files are written in JSON format and are stored in the 
#              directory "/ericsson/tor/data/access_control/policies/default/", 
#              each application has one policyset file, and there might have 
#              multiple policies in one policyset file. For the guide on defining 
#              the policies, please refer to 
#              "https://confluence-oss.lmera.ericsson.se/pages/viewpage.action?pageId=53845361"
#
# Parameters:  none
# Return:      0 (succeed)
#              1 (failed)
################################################################################
function parsePolicySets(){
    LogMessage "INFO: parsePolicySets request is received ...... Processing request"
    
    # If no application policy is available, just quite executing the script 
    file_count=`$LS $POLICYSETS 2>/dev/null | $WC -l`
    if [[ "$file_count" -lt "1" ]]
    then
        LogMessage "INFO: there is no application policy, skip parsing policy and creating role"
        exit 0
    fi
     
    for policy in $POLICYSETS
    do    	
        LogMessage "INFO: starts to parse policyset $policy"
        policy_Array=()
        let block_index=-1
        while read -r policyData
        do     
            if [[ $policyData =~ $POLICY_SPLITER ]] ; then
               ((block_index++))
               policy_Array[$block_index]=$policyData
            elif [[ $policyData =~ $DESCRIPTION_IDENTIFIER ]] ;then
                  policy_Array[$block_index]="${policy_Array[$block_index]}$policyData"
            elif [[ $policyData =~ $ROLE_IDENTIFIER && ! ${policy_Array[$block_index]} =~ $ROLE_IDENTIFIER ]] ;then
               policy_Array[$block_index]="${policy_Array[$block_index]}$policyData"
            fi
        done <"$policy"
        
        # parse each policy
        for (( index=0;index<${#policy_Array[@]};index++ ))
        do
           policy_desc=$(echo "${policy_Array[$index]}" |$GREP -Po '"'"Description"'"\s*:\s*"\K([^"]*)' | $SED 's/^ *//g' | $SED 's/ *$//g' )
           policy_role=$(echo "${policy_Array[$index]}" |$GREP -Po '"'"Role"'"\s*:\s*"\K([^"]*)' | $SED 's/^ *//g' | $SED 's/ *$//g' )
           if [ ! -z "$policy_role" -a "$policy_role" != "" ]  
           then
               if [[ -z "$policy_desc" ]]
               then
                   policy_desc=" "
               fi
               APP_ROLE_ARRAY[$NUM_COLUMN_IN_APP_ROLE_ARRAY*$POLICY_COUNT+$DESC_INDEX]="$policy_desc"
               APP_ROLE_ARRAY[$NUM_COLUMN_IN_APP_ROLE_ARRAY*$POLICY_COUNT+$ROLE_INDEX]="$policy_role"
               (( POLICY_COUNT++ ))
           else
               LogMessage "ERROR: Role name $policy_role is invalid"
               return 1
           fi
         done
         LogMessage "INFO: Done for parsing policyset $policy"
     done
 
     return 0
}

################################################################################
# Function:    createApplicationRoles
# Description: Create roles for the various applications based on the parsed 
#              results
#              Does not re-create the already existing roles
# Parameters:  none
# Return:      none
################################################################################
function createApplicationRoles() {
    LogMessage "INFO: createApplicationRoles request is received ...... Processing request"
    
    if [ -r "${SECADMIN_PASSKEY}" ]
    then 
        if [ -z "${default_security_admin_password}" ]
        then 
            LogMessage "ERROR: default_security_admin_password is not set in ${GLOBAL_PROPERTY_FILE}" 
            return 1 
        fi
        
        SECADMIN_PASSWORD=`echo ${default_security_admin_password} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${SECADMIN_PASSKEY}` 

        if [ -z "${SECADMIN_PASSWORD}" ]
        then
            LogMessage "ERROR: Failed to decrypt default_security_admin_password from ${GLOBAL_PROPERTY_FILE}"    
            return 1 
        fi 
    fi    
    
    #Get apache(httpd) host FQDN
    OPENIDM_HOST=`${GETENT} hosts httpd | awk '{print $4}'`
    rc=$?
    if [ $? -ne 0 ]; then
       LogMessage "ERROR: failed to get FQDN of apache(httpd) from getent, return-code: $rc"
       return 1
    fi
    if [ -z "$OPENIDM_HOST" ]; then
       LogMessage "ERROR: apache(httpd) host FQDN is null"
       return 1
    fi
    
    # Create session cookie
    $CURL --location-trusted --post302 --cookie-jar $COOKIE_FILE --cacert $SSO_CERT \
          -X POST "https://$OPENIDM_HOST/login" -d IDToken1=$SECADMIN_USER -d IDToken2=$SECADMIN_PASSWORD
    
    # Verify if the cookie is created or no.
    cookie=`$CAT $COOKIE_FILE |$GREP iPlanetDirectoryPro |$AWK '{print $7}'`
    if [ -z "${cookie}" ]; then
       LogMessage "ERROR: Failed to create a session cookie for $SECADMIN_USER"
       return 1
    fi
   
    for (( i=0; i<"$POLICY_COUNT";i++ )) 
    do
        role=${APP_ROLE_ARRAY[$NUM_COLUMN_IN_APP_ROLE_ARRAY*$i+$ROLE_INDEX]}
        description=${APP_ROLE_ARRAY[$NUM_COLUMN_IN_APP_ROLE_ARRAY*$i+$DESC_INDEX]}
        
        LogMessage "Info: Start to create role \"$role\" "
        
        queryRoleResult=`$CURL --header "X-Requested-With: XMLHttpRequest" \
                               --cookie $COOKIE_FILE --cacert $SSO_CERT \
                               "https://$OPENIDM_HOST/openidm/managed/role/$role"`
        if [[ "$queryRoleResult" =~ "roleName" ]] && [[ "$queryRoleResult" =~ "_id" ]]
        then
            LogMessage "INFO: The role \"$role\" already exists, skip creating this role"
        else
            res=`$CURL --header "X-Requested-With: XMLHttpRequest" \
                       --cookie $COOKIE_FILE --cacert $SSO_CERT \
                       --request PUT \
                       --data "{\"roleName\":\"$role\",\"description\":\"$description\"}" \
                       "https://$OPENIDM_HOST/openidm/managed/role/$role"`
             if [[ "$res" =~ "_id" ]] && [[ "$res" =~ "_rev" ]]; then
                 LogMessage  "INFO: Create role \"$role\" completed successfully" 
             else
                 LogMessage "ERROR: Create role \"$role\" failed"
                 return 1
             fi
        fi
    done
    # delete the session cookie file
    $RM -f $COOKIE_FILE
    LogMessage "INFO: createApplicationRoles completed successfully"
    return 0   
}

################################################################################
# Main Program
# Parameters: None
################################################################################
source $COMMON_SCRIPT
if [ $? != 0 ]; then
   echo "ERROR: Failed to source $COMMON_SCRIPT."
   exit 1
fi
SetLogFile
if [ $? != 0 ]; then
    echo "ERROR: SetLogFile failed"
    exit 1
fi

# we need the global.properties file
if [ ! -r "${GLOBAL_PROPERTY_FILE}" ]; then
   LogMessage "ERROR: Cannot read ${GLOBAL_PROPERTY_FILE}"
   exit 1
fi

. ${GLOBAL_PROPERTY_FILE}

LogMessage "INFO: Create application roles started..."

checkServiceStatus "opendj"
if [ $? != 0 ]; then
    LogMessage "ERROR: checkServiceStatus for opendj failed" 
    exit 1
fi

checkServiceStatus "openidm"
if [ $? != 0 ]; then
    LogMessage "ERROR: checkServiceStatus for openidm failed"
    exit 1
fi

checkServiceStatus "sso"
if [ $? != 0 ]; then
    LogMessage "ERROR: checkServiceStatus for sso failed"
    exit 1
fi

parsePolicySets
if [ $? != 0 ]; then
    LogMessage "ERROR: parsePolicySets failed"
    exit 1
fi

createApplicationRoles
if [ $? != 0 ]; then
    LogMessage "ERROR: createApplicationRoles failed"
    exit 1
fi

LogMessage "INFO: create_application_roles.sh completed successfully."

