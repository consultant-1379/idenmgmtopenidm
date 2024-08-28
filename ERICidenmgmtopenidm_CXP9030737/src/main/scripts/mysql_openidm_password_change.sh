#!/bin/bash

###############################################################################
# Copyright (c) 2014 Ericsson, Inc. All Rights Reserved.
# This script changes the OpenIDM and MySql root passwords
# Author: Bartlomiej Komonski (EBARKOM)
#
#
###############################################################################

  LOG_DIR="/var/log/openidm"
  DATENOW=$(/bin/date +"%Y-%m-%d-%H:%M:%z")
  LOG_FILE="${LOG_DIR}/mysql-openidm-password-change-${DATENOW}.log"

  GREP=/bin/grep
  SED=/bin/sed
  CUT=/bin/cut
  RM=/bin/rm
  CAT=/bin/cat
  CURL=/usr/bin/curl
  MYSQL=/opt/mysql/bin/mysql
  SSH=/usr/bin/ssh
  SCP=/usr/bin/scp
  SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

  # IDENMGMT deployment paths
  IDENMGMT_DIR=/opt/ericsson/com.ericsson.oss.security/idenmgmt
  COMMON_SCRIPT="$IDENMGMT_DIR/openidm/bin/common.sh"

  # OpenIDM deployment paths
  OpenIDM_HOME=/opt/openidm
  OpenIDM_CONF_DIR=$OpenIDM_HOME/conf

  # get datastore.properties settings
  PROPS_FILE=$IDENMGMT_DIR/config/datastore.properties

  # Certificate tool
  OPENSSL=/usr/bin/openssl

  # determine openidm host
  OPENIDM_HOST=""
  NODE_ID=`$CAT /etc/cluster/nodes/this/id`

  if [ "$NODE_ID" == "1" ]; then
     OPENIDM_HOST="openidmhost0"
  else
     OPENIDM_HOST="openidmhost1"
  fi

  MYSQL_ROOT_USER="root"
  MYSQL_LINUX_USER="idmmysql"
  MYSQL_HOST=idmdbhost

  OPENDJ_LOCAL_HOST="ldap-local"
  OPENDJ_REMOTE_HOST="ldap-remote"
  OPENDJ_REST_PORT="8447"

  OPENIDM_USER="openidm-admin"
  OPENIDM_PORT="8085"
  OPENIDM_SECURE_PORT="8445"

  MYSQL_OPENIDM_USER=openidm
  OPENIDM_PWD=""
  NEW_MYSQL_OPENIDM_PWD=""
  DM_PWD=""
  MYSQL_OPENIDM_PWD=""
  new_mysql_openidm_pwd=""

  SC1_HOST=`$GREP sc-1 /etc/hosts | awk '{print $4;}'`
  SC2_HOST=`$GREP sc-2 /etc/hosts | awk '{print $3;}'`
  MS_HOST=`$GREP monitoring-server /etc/hosts | awk '{print $3;}'`

  # determine apache server hostname
  APACHE_SERVER_ALIAS=`$GREP httpd /etc/hosts |awk '{print $4}'`
  APACHE_SERVER_CERT_FILE=/ericsson/tor/data/certificates/sso/ssoserverapache.crt

  # global properties that are either required by SSO or defined in the SED.
  GLOBAL_PROPERTY_FILE=/ericsson/tor/data/global.properties
. $GLOBAL_PROPERTY_FILE

  GLOBAL_PROPERTY_FILE_MS=/opt/ericsson/nms/litp/etc/cmw/packages/global.properties

  IDMMYSQL_PASSKEY=/ericsson/tor/data/idenmgmt/idmmysql_passkey
  OPENIDM_PASSKEY=/ericsson/tor/data/idenmgmt/openidm_passkey

###########################################################################################
# Function: UpdatePasswords
# Description: This function updates the root user passwords
# Parameters: None
# Return:  0 everything ok, 1 fail
###########################################################################################
UpdatePasswords()
{
  if [ -r "${IDMMYSQL_PASSKEY}" ]; then
    if [ -z "${idm_mysql_admin_password}" ]; then
      LogMessage "ERROR: idm_mysql_admin_password is not set in ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi

    MYSQL_OPENIDM_PWD=`echo ${idm_mysql_admin_password} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${IDMMYSQL_PASSKEY}`

    if [ -z "${MYSQL_OPENIDM_PWD}" ]; then
      LogMessage "ERROR: Failed to decrypt idm_mysql_admin_password from ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
  else
    LogMessage "ERROR: ${IDMMYSQL_PASSKEY} not found"
    return 1
  fi

  if [ -r "${OPENIDM_PASSKEY}" ]; then
    if [ -z "${openidm_admin_password}" ]; then
      LogMessage "ERRR: openidm_admin_password is not set in ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi

    OPENIDM_PWD=`echo ${openidm_admin_password} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${OPENIDM_PASSKEY}`

    if [ -z "${OPENIDM_PWD}" ]; then
      LogMessage "ERROR: Failed to decrypt openidm_admin_password from ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
  else
    LogMessage "ERROR: ${OPENIDM_PASSKEY} not found"
    return 1
  fi

   cd ${OpenIDM_HOME}

   sh cli.sh encrypt ${OPENIDM_PWD} > /tmp/idmpass

   idm_crypt_pass=`${SED} -n '/BEGIN ENCRYPTED/,/END ENCRYPTED/p' /tmp/idmpass | ${GREP} -v "ENCRYPTED VALUE" |  tr -d '\040\011\012\015'`

   ${RM} -f /tmp/idmpass

   TMP_DIR=/tmp
   lSqlScript=${TMP_DIR}/localPassScr.sql
   rSqlScript=${TMP_DIR}/remotePassScr.sql
   sqlOut=${TMP_DIR}/updatePasswd.out.$$

   ${CAT} << EOF > $lSqlScript
UPDATE openidm.internaluser  SET pwd='${idm_crypt_pass}' WHERE objectid='${OPENIDM_USER}';
UPDATE mysql.user SET Password=PASSWORD('${NEW_MYSQL_OPENIDM_PWD}') WHERE User='${MYSQL_OPENIDM_USER}';
UPDATE mysql.user SET Password=PASSWORD('${NEW_MYSQL_OPENIDM_PWD}') WHERE User='${MYSQL_ROOT_USER}';
FLUSH PRIVILEGES;
quit
EOF

    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to create temporary SQL script: [$lSqlScript]."
      return 1
    fi

    # transfer sql script to mysql host
    ${SCP} ${SSH_OPTS} ${lSqlScript} ${MYSQL_LINUX_USER}@${MYSQL_HOST}:${rSqlScript}

    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to transfer temporary SQL script [$lSqlScript] to ${MYSQL_HOST}."
      return 1
    fi

    # execute sql script remotely
    ${SSH} ${SSH_OPTS} ${MYSQL_LINUX_USER}@${MYSQL_HOST} "$MYSQL -u$MYSQL_ROOT_USER -p$MYSQL_OPENIDM_PWD < ${rSqlScript} > ${sqlOut} 2>&1"
    sleep 2

    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to execute the temporary SQL script: [${rSqlScript}]."
      LogMessage "ERROR: Refer to ${sqlOut} on ${MYSQL_HOST} for more details."
      return 1
    fi

    # remove remote sql script
    ${SSH} ${SSH_OPTS} ${MYSQL_LINUX_USER}@${MYSQL_HOST} "${RM} -f ${rSqlScript}"

    if [ $? -ne 0 ]; then
      LogMessage "WARN: Failed to remove SQL script [${rSqlScript}] on ${MYSQL_HOST}."
    fi

    # remove local sql script
    ${RM} -f ${lSqlScript} ${sqlOut}

  return 0
}

###############################################################################
#   This function updates openidm configuration files
#
##############################################################################
UpdateConfFile()
{
  REPO_JDBC_JSON=${OpenIDM_CONF_DIR}/repo.jdbc.json

  $SED -i 9,+9d $REPO_JDBC_JSON

  $SED -e 's/"password" : {/"password" : \"'${NEW_MYSQL_OPENIDM_PWD}'\",/gi' ${REPO_JDBC_JSON} > /tmp/repo.jdbc.json

  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $REPO_JDBC_JSON"
     return 1
  fi

  \cp /tmp/repo.jdbc.json $REPO_JDBC_JSON

  # Change ownership of the repo.jdbc.json file on SC-1
  ${SSH} ${SSH_OPTS} root@${SC1_HOST} "chown openidm:openidm $REPO_JDBC_JSON 2>&1"
  if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to update ownership of repo.jdbc.json in ${SC1_HOST}."
      return 1
  fi

  # Copy repo.jdbc.json file to target destination on SC-2
  ${SCP} ${SSH_OPTS} /tmp/repo.jdbc.json root@${SC2_HOST}:${REPO_JDBC_JSON}
  if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to copy repo.jdbc.json to target location in ${SC2_HOST}."
      return 1
  fi

   # Change ownership of the repo.jdbc.json file on SC-2
  ${SSH} ${SSH_OPTS} root@${SC2_HOST} "chown openidm:openidm $REPO_JDBC_JSON 2>&1"
  if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to update ownership of repo.jdbc.json in ${SC2_HOST}."
      return 1
  fi

  new_mysql_openidm_pwd=`echo ${NEW_MYSQL_OPENIDM_PWD} | ${OPENSSL} enc -a -e -aes-128-cbc -salt -kfile ${IDMMYSQL_PASSKEY}`

  $SED -e "s;idm_mysql_admin_password=${idm_mysql_admin_password};idm_mysql_admin_password=${new_mysql_openidm_pwd};gi" -e "s;openidm_admin_password=${idm_mysql_admin_password};openidm_admin_password=${new_mysql_openidm_pwd};gi" ${GLOBAL_PROPERTY_FILE} > /tmp/global.properties

  if [ $? -ne 0 ]; then
     LogMessage "ERROR: Failed to update ${GLOBAL_PROPERTY_FILE}"
     return 1
  fi

  \cp /tmp/global.properties ${GLOBAL_PROPERTY_FILE}

  # Copy global.properties file to target destination on MS-1
  ${SCP} ${SSH_OPTS} /tmp/global.properties root@${MS_HOST}:${GLOBAL_PROPERTY_FILE_MS}
  if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to update $GLOBAL_PROPERTY_FILE in ${MS_HOST}."
      return 1
  fi
  ${RM} -f /tmp/global.properties /tmp/repo.jdbc.json

  return 0
}

###############################################################################
#   This function checks if provided password matches to old password to allow continuation
#
##############################################################################
CheckOldPassword()
{
  LogMessage "CheckPassword request has been received. Processing request..."

  OLD_PASS=""

  if [ -r "${IDMMYSQL_PASSKEY}" ]; then
    if [ -z "${idm_mysql_admin_password}" ]; then
      LogMessage "ERROR: idm_mysql_admin_password is not set in ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi

    MYSQL_OPENIDM_PWD=`echo ${idm_mysql_admin_password} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${IDMMYSQL_PASSKEY}`

    if [ -z "${MYSQL_OPENIDM_PWD}" ]; then
      LogMessage "ERROR: Failed to decrypt idm_mysql_admin_password from ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
  else
    LogMessage "ERROR: ${IDMMYSQL_PASSKEY} not found"
    return 1
  fi

  x=0
  while [[ -z ${OLD_PASS} ]] || [[ $MYSQL_OPENIDM_PWD != $OLD_PASS ]]
  do
    LogMessage "Please enter current password"
    read -s OLD_PASS

    if [ -z ${OLD_PASS} ]; then
      LogMessage "ERROR: No password provided"
    else 
      if [[ $MYSQL_OPENIDM_PWD != $OLD_PASS ]]; then
        LogMessage "ERROR: Wrong password provided"
      fi
    fi
   
    if [[ $x -eq 2  ]] ; then
      LogMessage "ERROR: Wrong password provided three times. Exiting..."
      return 1
    fi

    x=$[x+1]
  done	

  return 0
}

###############################################################################
#   This function checks if provided password matches password policies
#
##############################################################################
CheckProvidedNewPassword()
{

  LogMessage "CheckProvidedNewPassword request has been received. Processing request..."
  LogMessage  "Please type new password"

  read -s NEW_MYSQL_OPENIDM_PWD

  x=0

  while [[ $NEW_MYSQL_OPENIDM_PWD == $OLD_PASS  ]] || ! [[ ${#NEW_MYSQL_OPENIDM_PWD} -ge 8 && "$NEW_MYSQL_OPENIDM_PWD" == *[A-Z]** && "$NEW_MYSQL_OPENIDM_PWD" == *[0-9]* && "$NEW_MYSQL_OPENIDM_PWD" =~ ^[-A-Za-z_0-9.]+$ ]] 
  do
    if [[ $x -eq 2  ]] ; then
      LogMessage "ERROR: Wrong password provided three times. Exiting..."
      return 1
    else 
      if [[ $NEW_MYSQL_OPENIDM_PWD == $OLD_PASS  ]] ; then
        LogMessage "New password must be different then current password."
      else
        LogMessage "The password should be at least 8 characters, one digit, one capital letter and only hyphen ( - ), underscore ( _ ), and period ( . ) are allowed in password."
      fi
    fi

   x=$[x+1]
   LogMessage "Enter new password:"
   read -s NEW_MYSQL_OPENIDM_PWD
  done

  LogMessage "Repeat new password"
  read -s REP_PASS

  x=0

  while [[ $NEW_MYSQL_OPENIDM_PWD != $REP_PASS ]]
  do
   LogMessage "ERROR: Passwords do not match"
   x=$[x+1]

   if [[ $x -eq 3  ]] ; then
    LogMessage "ERROR: Wrong password provided three times. Exiting..."
    return 1
   fi
   LogMessage "Repeat new password"
   read -s REP_PASS
  done

  return 0
}

###############################################################################
# Main Program
# Parameters: None
###############################################################################
  source $COMMON_SCRIPT
if [ "${NODE_ID}" == "1" ]; then
  REP_PASS=""

  LogMessage  "OpenIdm administrator password and mysql root password change."

  if [ $? != 0 ]; then
   echo "ERROR: Failed to source $COMMON_SCRIPT."
   exit 1
  fi

  CheckOldPassword

  if [ $? != 0 ]; then
   echo "ERROR: CheckOldpassword failed."
   exit 1
  fi

  CheckProvidedNewPassword

  if [ $? != 0 ]; then
   echo "ERROR: CheckProvidedNewPassword failed."
   exit 1
  fi

  UpdatePasswords

  if [ $? != 0 ]; then
   LogMessage "ERROR: UpdatePasswords failed."
   exit 1
  fi

  UpdateConfFile

  if [ $? != 0 ]; then
   LogMessage "ERROR: UpdateConfFile failed."
   exit 1
  fi

  LogMessage "Password changed successfully..."

  exit 0
else
    LogMessage "Script can be executed only from Service Controller 1 (SC1)"
    exit 1
fi

