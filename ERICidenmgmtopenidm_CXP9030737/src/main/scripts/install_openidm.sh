#/bin/ksh
################################################################################
# Copyright (c) 2014 Ericsson, Inc. All Rights Reserved.
# This script installs the OpenIDM server
# 
# 
###############################################################################

   # OpenIDM JVM settings
   DEFAULT_FR_XMX=-Xmx1024m
   XMS=-Xms1536m
   XMX=-Xmx1536m

   LOG_DIR="/var/log/openidm"
   DATENOW=$(/bin/date +"%Y-%m-%d-%H:%M:%z")
   LOG_FILE="${LOG_DIR}/openidm-install-${DATENOW}.log"
   AUDIT_LOG_DIR="${LOG_DIR}/audit"

   MKDIR=/bin/mkdir
   GREP=/bin/grep
   SED=/bin/sed
   CUT=/bin/cut
   RM=/bin/rm
   MV=/bin/mv
   CAT=/bin/cat
   TAR=/bin/tar
   CHOWN=/bin/chown
   CHMOD=/bin/chmod
   CHGRP=/bin/chgrp
   CURL=/usr/bin/curl
   LDAPSEARCH=/opt/opendj/bin/ldapsearch
   LDAPMODIFY=/opt/opendj/bin/ldapmodify
   MYSQL=/opt/mysql/bin/mysql
   SSH=/usr/bin/ssh
   SCP=/usr/bin/scp
   SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
   AWK=/bin/awk
   GETENT=/usr/bin/getent

   # IDENMGMT deployment paths
   IDENMGMT_DIR=/opt/ericsson/com.ericsson.oss.security/idenmgmt
   COMMON_SCRIPT="$IDENMGMT_DIR/openidm/bin/common.sh"
   BACKUP_DIR="/ericsson/tor/data"
   LOG_ROTATION_DIR="/etc/logrotate.d"
   OPENIDM_SSL_EXT_FILE="${IDENMGMT_DIR}/openidm/config/openidm-ssl-ext-ca.cnf"

   # OpenIDM deployment paths
   OpenIDM_HOME=/opt/openidm
   OpenIDM_BUNDLE_DIR=$OpenIDM_HOME/bundle
   OpenIDM_CONN_DIR=$OpenIDM_HOME/connectors
   OpenIDM_CONF_DIR=$OpenIDM_HOME/conf
   OpenIDM_SCRIPT_DIR=$OpenIDM_HOME/script
   OpenIDM_DEFAULTS_SCRIPT_DIR=$OpenIDM_HOME/bin/defaults/script
   OPENIDM_BOOT_PROPERTIES_FILE="${OpenIDM_HOME}/conf/boot/boot.properties"

   # OpenIDM Constants Definition
   OpenIDM_USER=openidm
   OpenIDM_GROUP=openidm
   
   # get datastore.properties settings
   PROPS_FILE=$IDENMGMT_DIR/config/datastore.properties
   SUPER_USER_PASSWD_POLICY=`$GREP superuserPasswdPolicy  $PROPS_FILE | $CUT -d= -f2` 

   # Certificate tools
   OPENSSL=/usr/bin/openssl
   JAVA_KEYTOOL=/usr/java/default/bin/keytool
   JAVA=/usr/java/default/bin/java
   KEYSTORE_NAME=$OpenIDM_HOME/security/keystore.jceks
   TRUSTSTORE_NAME=$OpenIDM_HOME/security/truststore
   ROOTCA_DIR="/ericsson/tor/data/certificates"
   ROOTCA_FILE=$ROOTCA_DIR/rootCA.pem
   ROOTCA_KEY_FILE=$ROOTCA_DIR/rootCA.key
   KEY_VALIDITY_PERIOD=7300
   KEYSTORE_PWD="changeit"
   STORE_TYPE=jceks
   
   # OpenIDM Operation Command
   OpenIDM_Start="/etc/init.d/openidm start"
   OpenIDM_Stop="/etc/init.d/openidm stop"
   OpenIDM_Status="/etc/init.d/openidm status"
   
   # Default Security Administrator and Default Roles Definition
   DEFAULT_ADMIN_ROLES="SECURITY_ADMIN ADMINISTRATOR"
   DEFAULT_ROLES="SECURITY_ADMIN OPERATOR ADMINISTRATOR FIELD_TECHNICIAN"
   SECURIY_ADMIN_UID="administrator"
   SECURIY_ADMIN_FIRST_NAME="security"
   SECURIY_ADMIN_LAST_NAME="admin"
   SECURIY_ADMIN_EMAIL="security@administor.com"
   SECURIY_ADMIN_UTYPE="enmUser"
   SECURITY_ADMIN_PWD=""

   # determine openidm host
   LOCAL_HOSTNAME=`$CAT /etc/cluster/nodes/this/hostname`
   PEER_HOSTNAME=`$CAT /etc/cluster/nodes/peer/hostname`
   OPENIDM_HOST=""

   NODE_ID=`$CAT /etc/cluster/nodes/this/id`
   if [ "$NODE_ID" == "1" ]; then
      OPENIDM_HOST="openidmhost0"
   else
      OPENIDM_HOST="openidmhost1"
   fi

   MYSQL_ROOT_USER="root"
   MYSQL_LINUX_USER="idmmysql"
   MYSQL_HOST="idmdbhost"

   OPENDJ_LOCAL_HOST="ldap-local"
   OPENDJ_REMOTE_HOST="ldap-remote"
   OPENDJ_REST_PORT="8447"

   OPENIDM_USER="openidm-admin"
   OPENIDM_PORT="8085"
   OPENIDM_SECURE_PORT="8445"
   MYSQL_OPENIDM_USER=openidm

   OPENIDM_PWD=""
   MYSQL_OPENIDM_PWD=""
   DM_PWD=""

   # Apache server digital certificate
   APACHE_SERVER_CERT_FILE=/ericsson/tor/data/certificates/sso/ssoserverapache.crt


#####################################################################################
# Function:  UnzipSource
# Description: unzip the source tarball.
# Parameters:  nothing 
# Returns:    0  success
#             1  fail
#####################################################################################
UnzipSource()
{
  \cp -rf ${IDENMGMT_DIR}/openidm/pkg/openidm.tar.gz /opt
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to run:  cp ${IDENMGMT_DIR}/openidm/pkg/openidm.tar.gz /opt "
    return 1
  fi
  cd /opt
  /bin/rm -rf $OpenIDM_HOME  > /dev/null 2>&1
  if [ $? != 0 ] ; then
     LogMessage "ERROR: Failed to run:  /bin/rm -rf $OpenIDM_HOME"  
     return 1
  fi
  
  tar -zxf openidm.tar.gz
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to expand openidm.tar.gz  while running: tar -zxvf openidm.tar.gz "
    return 1
  fi
  rm openidm.tar.gz

  CopyFiles
  if [ $? != 0 ] ; then
     LogMessage "ERROR: CopyFiles failed."
     return 1
  fi

  UpdatePasswords
  if [ $? != 0 ]; then
    LogMessage "ERROR: UpdatePasswords failed."
    return 1
  fi

  UpdateConfigFiles
  if [ $? != 0 ] ; then
     LogMessage "ERROR: UpdateConfigFiles failed."
     return 1
  fi

  #change group and ownership of OpenIDM home dir
  cd $OpenIDM_HOME
  $CHOWN -R $OpenIDM_USER .
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to change ownership of openidm home dir"
    return 1
  fi
  $CHGRP -R $OpenIDM_GROUP .
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to change group of openidm home dir"
    return 1
  fi

  #change group and ownwrship of openidm data dir
  cd $IDENMGMT_DIR/openidm
  $CHOWN -R $OpenIDM_USER .
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to change ownership of openidm data dir"
    return 1
  fi
  $CHGRP -R $OpenIDM_GROUP .
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to change group of openidm data dir"
    return 1
  fi


  LogMessage "Success UnzipSource "
  return 0
}

#################################################################
# uncompress the jetty policy agent tar.gz into /opt/openidm
#
# argument: none
# returns:
#   0       success
#   1       failure
#################################################################
UnzipJettyPolicyAgent()
{
  LogMessage "INFO: start to uncompress/install jetty policy agent"

  # copy and uncompress the file
  JETTY_TAR=${IDENMGMT_DIR}/openidm/pkg/j2ee_agents-policy-agent.tar.gz
  JETTY_DIR=/opt/openidm
  \cp -rf ${JETTY_TAR}  ${JETTY_DIR}
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${JETTY_TAR} to ${JETTY_DIR}"
    return 1
  fi
  cd ${JETTY_DIR}
  ${RM} -rf j2ee_agents
  ${TAR} -zxf j2ee_agents-policy-agent.tar.gz
  retcode=$?
  if [ $retcode -eq 0 ]; then
    LogMessage "INFO: uncompressed j2ee_agents-policy-agent.tar.gz"
  else
    LogMessage "ERROR: failed to uncompress j2ee_agents-policy-agent.tar.gz, return-code: $retcode"
    return 1
  fi
  ${RM} -rf j2ee_agents-policy-agent.tar.gz

  # create required sub-directories
  JETTY_IDM_DIR=${JETTY_DIR}/j2ee_agents/jetty_v7_agent/openidm
  ${MKDIR} -p ${JETTY_IDM_DIR}
  retcode=$?
  if [ $? -eq 0 ]; then
    LogMessage "INFO: created directory ${JETTY_IDM_DIR}"
  else
    LogMessage "ERROR: failed to create directory ${JETTY_IDM_DIR}, return-code: $retcode"
    return 1
  fi
  ${MKDIR} -p ${JETTY_IDM_DIR}/config
  ${MKDIR} -p ${JETTY_IDM_DIR}/logs
  ${MKDIR} -p ${JETTY_IDM_DIR}/logs/audit
  ${MKDIR} -p ${JETTY_IDM_DIR}/logs/debug
  ${MKDIR} -p ${JETTY_DIR}/script/security

  # copy the config files and set file ownership
  \cp ${IDENMGMT_DIR}/openidm/jetty_conf/servletfilter-openam.json ${JETTY_DIR}/conf
  \cp ${IDENMGMT_DIR}/openidm/jetty_conf/populateContext.js ${JETTY_DIR}/script/security

  # get httpd host FQDN
  httpdfqdn=`${GETENT} hosts httpd |${AWK} '{print $4}'`
  retcode=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get FQDN of httpd from getent, return-code: $retcode"
    return 1
  fi
  if [ -z "$httpdfqdn" ]; then
    LogMessage "ERROR: httpd FQDN is null"
    return 1
  fi
  # get httpd host IP
  httpdHostIP=`${GETENT} hosts httpd | ${AWK} '{print $1}'`
  retcode=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get IP of httpd from getent, return-code: $retcode"
    return 1
  fi
  if [ -z "$httpdHostIP" ]; then
    LogMessage "ERROR: httpd host IP is null"
    return 1
  fi
  # get SC1 IP
  sc1IP=`${GETENT} hosts sc-1 | ${AWK} '{print $1}'`
  retcode=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get IP of SC1 from getent, return-code: $retcode"
    return 1
  fi
  if [ -z "$sc1IP" ]; then
    LogMessage "ERROR: SC1 IP is null"
    return 1
  fi
  # get SC2 IP
  sc2IP=`${GETENT} hosts sc-2 | ${AWK} '{print $1}'`
  retcode=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get IP of SC2 from getent, return-code: $retcode"
    return 1
  fi
  if [ -z "$sc2IP" ]; then
    LogMessage "ERROR: SC2 IP is null"
    return 1
  fi

  # set fqdn.default to openidmhost0 on SC-1, and openidmhost1 on SC-2
  ${SED} "s/apache.vts.com/${httpdfqdn}/g" ${IDENMGMT_DIR}/openidm/jetty_conf/OpenSSOAgentConfiguration.properties |sed "s/FQDN.DEFAULT/${OPENIDM_HOST}/" > ${JETTY_IDM_DIR}/config/OpenSSOAgentConfiguration.properties
  ${SED} "s/apache.vts.com/${httpdfqdn}/g" ${IDENMGMT_DIR}/openidm/jetty_conf/OpenSSOAgentBootstrap.properties > ${JETTY_IDM_DIR}/config/OpenSSOAgentBootstrap.properties
  LogMessage "INFO: copied config files to jetty directory"

  # to set the proxy/reverseProxy hostname to openidmhost0 on SC-1, and openidmhost1 on SC-2, for httpd
  if [ -e /etc/httpd/conf.d/virtualhost_includes/ ]; then
    if [ -f /etc/httpd/conf.d/virtualhost_includes/openidm.conf ]; then
       ${MV} -f /etc/httpd/conf.d/virtualhost_includes/openidm.conf /etc/httpd/conf.d/virtualhost_includes/openidm.conf.old
       LogMessage "WARN: file should have not existed: /etc/httpd/conf.d/virtualhost_includes/openidm.conf, so it is moved"
    fi
    ${SED} "s/OPENIDM.HOST/${OPENIDM_HOST}/g; s/HTTPD.HOST.IP/${httpdHostIP}/g; s/SC1.IP/${sc1IP}/g; s/SC2.IP/${sc2IP}/g" ${IDENMGMT_DIR}/openidm/jetty_conf/openidm.conf > /etc/httpd/conf.d/virtualhost_includes/openidm.conf
    /bin/chmod 644 /etc/httpd/conf.d/virtualhost_includes/openidm.conf
    LogMessage "INFO: updated /etc/httpd/conf.d/virtualhost_includes/openidm.conf"
  else
    LogMessage "ERROR: missing directory /etc/httpd/conf.d/virtualhost_includes"
    return 1
  fi

  ${CHOWN} -R openidm:openidm ${JETTY_DIR}/conf/servletfilter-openam.json
  ${CHOWN} -R openidm:openidm ${JETTY_DIR}/script/security/
  ${CHOWN} -R openidm:openidm ${JETTY_DIR}/j2ee_agents
  ${RM} -rf /opt/openidm/bundle/openidm-filter-2.1.0.jar /opt/openidm/felix-cache/
  LogMessage "INFO: removed openidm filter and cache"

  LogMessage "INFO: jetty policy agent is installed successfully"
  return 0
}

###########################################################################################
# Function: HardenOpenidm
# Description: This function hardens OpenIDM:
#              It disables Jetty's non-ssl port
#              Sets the right permissions for OpenIDM file system 
#              Removes the OSGI console
#              Removes the samples directory
#              Removes OpenIDM default UI
#              Removes the embedded Orient DB and its console
# Note:        Removing all the default trusted certificates that come with OpenIDM is
#              done in ConfigOpenidmCertificates function
# Parameters: None
# Return:  0 everything ok, 1 fail
###########################################################################################
HardenOpenidm()
{

  LogMessage "HardenOpenidm request has been received. Processing request..."
  #Change permissions and owernship for Openidm directories and files
  chmod -R o-rwx $OpenIDM_HOME
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: Failed to change permissions for Openidm directories and files"
     return 1
  fi
  $CHOWN -R $OpenIDM_USER:$OpenIDM_USER $OpenIDM_HOME
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: Failed to change ownership for Openidm directories and files"
     return 1
  fi

  #remove OpenIDM's non secure port from jetty.xml
  \mv -f $OpenIDM_CONF_DIR/secure_jetty.xml $OpenIDM_CONF_DIR/jetty.xml 
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove OpenIDM's non secure port from $OpenIDM_CONFT_DIR/jetty.xml"
    return 1
  fi

  #Remove the OSGI web console
  \rm -rf $OpenIDM_BUNDLE_DIR/org.apache.felix.webconsole-3.1.8.jar 

  #Remove the samples directory
  \rm -rf  $OpenIDM_HOME/samples 

  #Remove the default UIdirectory
  \rm -rf  $OpenIDM_HOME/ui 

  #Remove the embedded Orient DB and its console
  \rm -rf  $OpenIDM_BUNDLE_DIR/orientdb-server-1.3.0.jar
  \rm -rf  $OpenIDM_BUNDLE_DIR/orientdb-enterprise-1.3.0.jar
  \rm -rf  $OpenIDM_BUNDLE_DIR/orientdb-core-1.3.0.jar
  \rm -rf  $OpenIDM_BUNDLE_DIR/orientdb-client-1.3.0.jar
  \rm -rf  $OpenIDM_BUNDLE_DIR/orient-commons-1.3.0.jar
  \rm -rf  $OpenIDM_BUNDLE_DIR/openidm-repo-orientdb-2.1.0.jar

  LogMessage "HardenOpenidm completed successfully"
  return 0

}

#################################################################
# BackupOpenidm: Takes a backup of Openidm configuration
# Arguments: None
#
# Returns:
#   0      Success
#   1      Failure
#################################################################
BackupOpenidm(){

   LogMessage "INFO: BackupOpenidm invoked, processing request .........."

   DATENOW=$(/bin/date +"%Y-%m-%d-%H:%M")
   cd /
   $TAR cf $BACKUP_DIR/openidm-backup.tar-${DATENOW} -C / opt/openidm \
                                                         opt/ericsson/com.ericsson.oss.security/idenmgmt/openidm \
                                                         var/log/openidm
   if [ $? != 0 ] ; then
        LogMessage "ERROR: Failed to take a backup of Openidm configuration"
        return 1
   fi

   LogMessage "INFO: BackupOpenidm completed successfully"
   return 0
}

#####################################################################################
# Function:  CopyFiles
# Description: copies sql data files, jetty.xml, jdbc.json, connector/J and cleans up orientdb.json 
# Parameters:  nothing 
# Returns:    0  success
#             1  fail
#####################################################################################
#
CopyFiles()
{
  \cp -rf  ${IDENMGMT_DIR}/openidm/bundle/mysql-connector-java-*.jar $OpenIDM_BUNDLE_DIR 
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${IDENMGMT_DIR}/openidm/bundle/mysql-connector-java-*-bin.jar  to  $OpenIDM_BUNDLE_DIR  " 
    return 1
  fi
 
  \cp -rf  ${IDENMGMT_DIR}/openidm/bundle/openidm-core-2.1.0_OPENIDM-2500.tpatch.jar $OpenIDM_BUNDLE_DIR 
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${IDENMGMT_DIR}/openidm/bundle/openidm-core-2.1.0_OPENIDM-2500.tpatch.jar  to  $OpenIDM_BUNDLE_DIR  " 
    return 1
  fi
 
  \cp -rf  ${IDENMGMT_DIR}/openidm/bundle/openidm-provisioner-openicf-patch-2.1.0.jar $OpenIDM_BUNDLE_DIR 
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${IDENMGMT_DIR}/openidm/bundle/openidm-provisioner-openicf-patch-2.1.0.jar  to  $OpenIDM_BUNDLE_DIR  " 
    return 1
  fi
  
  \cp -rf  ${IDENMGMT_DIR}/openidm/bundle/ldap-connector-1.1.1.1.jar $OpenIDM_CONN_DIR
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${IDENMGMT_DIR}/openidm/bundle/ldap-connector-1.1.1.1.jar  to  $OpenIDM_CONN_DIR  " 
    return 1
  fi

  \cp -rf  ${IDENMGMT_DIR}/openidm/bundle/sessioninvalidation.jar $OpenIDM_BUNDLE_DIR
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy ${IDENMGMT_DIR}/openidm/bundle/sessioninvalidation.jar  to  $OpenIDM_BUNDLE_DIR  " 
    return 1
  fi
  
  \cp -rf ${IDENMGMT_DIR}/openidm/conf/* $OpenIDM_CONF_DIR 
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy   ${IDENMGMT_DIR}/openidm/conf/*  $OpenIDM_CONF_DIR " 
    return 1
  fi
 
  \cp -rf ${IDENMGMT_DIR}/openidm/script/* $OpenIDM_SCRIPT_DIR
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to copy   ${IDENMGMT_DIR}/openidm/script/*  $OpenIDM_SCRIPT_DIR "
    return 1
  fi

  \mv -f $OpenIDM_SCRIPT_DIR/policy.js $OpenIDM_DEFAULTS_SCRIPT_DIR/
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to move $OpenIDM_SCRIPT_DIR/policy.js $OpenIDM_DEFAULTS_SCRIPT_DIR"
    return 1
  fi

  \mv -f $OpenIDM_CONF_DIR/openidmlog $LOG_ROTATION_DIR/
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to move $OpenIDM_CONF_DIR/openidmlog $LOG_ROTATION_DIR"
    return 1
  fi

  \rm -rf  ${IDENMGMT_DIR}/openidm/bundle/
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove ${IDENMGMT_DIR}/openidm/bundle/"
    return 1
  fi

  \rm -rf  ${IDENMGMT_DIR}/openidm/conf/
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove ${IDENMGMT_DIR}/openidm/conf/"
    return 1
  fi

  \rm -rf  ${IDENMGMT_DIR}/openidm/script/
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove ${IDENMGMT_DIR}/openidm/script/"
    return 1
  fi

  \rm -rf  $OpenIDM_CONF_DIR/repo.orientdb.json
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove  $OpenIDM_CONF_DIR/repo.orientdb.json" 
    return 1
  fi

  \rm -rf  $OpenIDM_CONN_DIR/ldap-connector-1.1.0.1.jar
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove  $OpenIDM_CONN_DIR/ldap-connector-1.1.0.1.jar" 
    return 1
  fi

  \rm -rf  $OpenIDM_BUNDLE_DIR/openidm-provisioner-openicf-2.1.0.jar
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove  $OpenIDM_BUNDLE_DIR/openidm-provisioner-openicf-2.1.0.jar" 
    return 1
  fi

  \rm -rf  $OpenIDM_BUNDLE_DIR/openidm-core-2.1.0.jar
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove  $OpenIDM_BUNDLE_DIR/openidm-core-2.1.0.jar" 
    return 1
  fi

  \rm -rf  $OpenIDM_HOME/startup.bat
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to remove $OpenIDM_HOME/startup.bat"
    return 1
  fi

  LogMessage "Success  CopyFiles"

  return 0
}

###############################################################################
#   Updates passwords related to OpenIDM admin and MySQL
#
##############################################################################
UpdatePasswords(){

  OPENDJ_PASSKEY=/ericsson/tor/data/idenmgmt/opendj_passkey
  IDMMYSQL_PASSKEY=/ericsson/tor/data/idenmgmt/idmmysql_passkey
  OPENIDM_PASSKEY=/ericsson/tor/data/idenmgmt/openidm_passkey
  SECADM_PASSKEY=/ericsson/tor/data/idenmgmt/secadmin_passkey

  LogMessage "UpdatePasswords invoked, processing request..."

  if [ -r "${OPENDJ_PASSKEY}" ]; then
    DM_PWD=`echo ${LDAP_ADMIN_PASSWORD} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${OPENDJ_PASSKEY}`
    if [ -z "${DM_PWD}" ]; then
      LogMessage "ERROR: Failed to decrypt LDAP_ADMIN_PASSWORD from ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
  else
    LogMessage "ERROR: ${OPENDJ_PASSKEY} not found"
    return 1
  fi

  if [ -r "${SECADM_PASSKEY}" ]; then
    if [ -z "${default_security_admin_password}" ]; then
      LogMessage "ERROR: default_security_admin_password is not set in ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
    SECURITY_ADMIN_PWD=`echo ${default_security_admin_password} | ${OPENSSL} enc -a -d -aes-128-cbc -salt -kfile ${SECADM_PASSKEY}`
    if [ -z "${SECURITY_ADMIN_PWD}" ]; then
      LogMessage "ERROR: Failed to decrypt default_security_admin_password from ${GLOBAL_PROPERTY_FILE}"
      return 1
    fi
  else
    LogMessage "ERROR: ${SECADM_PASSKEY} not found"
    return 1
  fi

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
      LogMessage "ERROR: openidm_admin_password is not set in ${GLOBAL_PROPERTY_FILE}"
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

  LogMessage "UpdatePasswords completed successfully..."
  return 0
}

###############################################################################
#   Updates various passwords in MySQL database
#   Change passwords in MySQL (only do this from sc-1)
#     1) openidm-admin user password
#     2) mysql root user password
#     3) openidm user password
#
##############################################################################
UpdatePasswordsInMySQL(){
  # Change the default OpenIDM admin password in MySQL (only required from sc-1)
  if [ "${NODE_ID}" == "1" ]; then
    cd ${OpenIDM_HOME}
    sh cli.sh encrypt ${OPENIDM_PWD} > /tmp/idmpass
    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to encrypt ${OPENIDM_USER} password"
      return 1
    fi

    idm_crypt_pass=`${SED} -n '/BEGIN ENCRYPTED/,/END ENCRYPTED/p' /tmp/idmpass | ${GREP} -v "ENCRYPTED VALUE" |  tr -d '\040\011\012\015'`
    if [ -z "${idm_crypt_pass}" ]; then
      LogMessage "ERROR: Failed to update ${OPENIDM_USER} password"
      return 1
    fi
    ${RM} -f /tmp/idmpass

    TMP_DIR=/tmp
    lSqlScript=${TMP_DIR}/localPassScr.sql
    rSqlScript=${TMP_DIR}/remotePassScr.sql
    sqlOut=${TMP_DIR}/updatePasswd.out.$$

    ${CAT} << EOF > $lSqlScript
UPDATE openidm.internaluser  SET pwd='${idm_crypt_pass}' WHERE objectid='${OPENIDM_USER}';
UPDATE mysql.user SET Password=PASSWORD('${MYSQL_OPENIDM_PWD}') WHERE User='${MYSQL_OPENIDM_USER}';
UPDATE mysql.user SET Password=PASSWORD('${MYSQL_OPENIDM_PWD}') WHERE User='${MYSQL_ROOT_USER}';
FLUSH PRIVILEGES;
quit
EOF

    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to create temporary SQL script: [$lSqlScript]."
      return 1
    fi

    # transfer sql script to mysql host
    ${SCP} ${SSH_OPTS} ${lSqlScript} ${MYSQL_LINUX_USER}@${MYSQL_HOST}:/${rSqlScript}
    if [ $? -ne 0 ]; then
      LogMessage "ERROR: Failed to transfer temporary SQL script [$lSqlScript] to ${MYSQL_HOST}."
      return 1
    fi

    # execute sql script remotely
    ${SSH} ${SSH_OPTS} ${MYSQL_LINUX_USER}@${MYSQL_HOST} "$MYSQL -u$MYSQL_ROOT_USER < ${rSqlScript} > ${sqlOut} 2>&1"
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
    ${RM} -f ${lSqlScript}

    LogMessage "UpdatePasswordsInMySQL completed successfully..."
  fi

  return 0
}

###############################################################################
#   This function updates openidm config files
#
##############################################################################
UpdateConfigFiles(){
 
  LogMessage "UpdateConfigFiles invoked, processing request..."

  # Update JVM setting in startup.sh
  OPENIDM_JVM_SETTINGS=${OpenIDM_HOME}/startup.sh

  $SED -e "s/OPENIDM_OPTS=\"${DEFAULT_FR_XMX}\"/OPENIDM_OPTS=\"$XMS $XMX\"/g" $OPENIDM_JVM_SETTINGS > /tmp/temp_openidm_startup.sh
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $OPENIDM_JVM_SETTINGS"
     return 1
  fi
  \cp /tmp/temp_openidm_startup.sh $OPENIDM_JVM_SETTINGS

  REPO_JDBC_JSON=${OpenIDM_CONF_DIR}/repo.jdbc.json

  $SED -e "s/MYSQL_HOST/${MYSQL_HOST}/g" -e "s/MYSQL_OPENIDM_PASSWORD/${MYSQL_OPENIDM_PWD}/g" $REPO_JDBC_JSON > /tmp/repo.jdbc.json
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $REPO_JDBC_JSON"
     return 1
  fi 
  \cp /tmp/repo.jdbc.json $REPO_JDBC_JSON

  OPENICF_LDAP_JSON=${OpenIDM_CONF_DIR}/provisioner.openicf-ldap.json
  $SED -e "s/DM_DN/$LDAP_ADMIN_CN/g" -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" -e "s/DM_PWD/$DM_PWD/g" -e "s/LDAP_PORT/${COM_INF_LDAP_PORT}/g" -e "s/OPENDJ_LOCAL_HOSTNAME/${OPENDJ_LOCAL_HOST}/g" -e "s/OPENDJ_REMOTE_HOSTNAME/${OPENDJ_REMOTE_HOST}/g" $OPENICF_LDAP_JSON > /tmp/provisioner.openicf-ldap.json
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $OPENICF_LDAP_JSON"
     return 1
  fi
  \cp /tmp/provisioner.openicf-ldap.json  $OPENICF_LDAP_JSON

  SCHEDULER_JSON=${OpenIDM_CONF_DIR}/scheduler.json
  $SED -e "s/NODENAME/$OPENIDM_HOST/g" $SCHEDULER_JSON > /tmp/scheduler.json
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $SCHEDULER_JSON"
     return 1
  fi
  \cp /tmp/scheduler.json $SCHEDULER_JSON

  UPDATE_LDAP_JS=${OpenIDM_SCRIPT_DIR}/updateLdap.js
  $SED -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" $UPDATE_LDAP_JS > /tmp/updateLdap.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $UPDATE_LDAP_JS"
     return 1
  fi
  \cp /tmp/updateLdap.js  $UPDATE_LDAP_JS

  IS_VALID_SYNC_JS=${OpenIDM_SCRIPT_DIR}/isValidSync.js
  $SED -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" $IS_VALID_SYNC_JS > /tmp/isValidSync.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $IS_VALID_SYNC_JS"
     return 1
  fi
  \cp /tmp/isValidSync.js  $IS_VALID_SYNC_JS
   
  UPDATE_ROLE_JS=${OpenIDM_SCRIPT_DIR}/updateRole.js
  $SED -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" $UPDATE_ROLE_JS > /tmp/updateRole.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $UPDATE_ROLE_JS"
     return 1
  fi
  \cp /tmp/updateRole.js  $UPDATE_ROLE_JS

  CREATE_ROLE_JS=${OpenIDM_SCRIPT_DIR}/createRole.js
  $SED -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" $CREATE_ROLE_JS > /tmp/createRole.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $CREATE_ROLE_JS"
     return 1
  fi
  \cp /tmp/createRole.js  $CREATE_ROLE_JS

  SYNC_JSON=${OpenIDM_CONF_DIR}/sync.json
  $SED -e "s/BASE_DN/$COM_INF_LDAP_ROOT_SUFFIX/g" $SYNC_JSON > /tmp/sync.json
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $SYNC_JSON"
     return 1
  fi 
  \cp /tmp/sync.json  $SYNC_JSON

  MANAGE_PASSWORD_JS=${OpenIDM_SCRIPT_DIR}/managePassword.js
  $SED -e "s/OPENDJ_REST_HOST_PORT/${OPENDJ_LOCAL_HOST}:${OPENDJ_REST_PORT}/g" $MANAGE_PASSWORD_JS > /tmp/managePassword.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $MANAGE_PASSWORD_JS"
     return 1
  fi
  \cp /tmp/managePassword.js  $MANAGE_PASSWORD_JS

  SYSTEM_PROPS=${OpenIDM_CONF_DIR}/system.properties

  $SED -e "s%OPENIDM_HOME%${OpenIDM_HOME}%g" ${SYSTEM_PROPS} > /tmp/system.properties
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update ${SYSTEM_PROPS}"
     return 1
  fi
  \cp /tmp/system.properties ${SYSTEM_PROPS}
  
  MANAGE_ROLE_JS=${OpenIDM_SCRIPT_DIR}/manageRole.js

  # get apache server host FQDN
  APACHE_SERVER_ALIAS=`${GETENT} hosts httpd |${AWK} '{print $4}'`
  rc=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get apache(httpd) host FQDN from getent, return code: $rc"
    return 1
  fi
  if [ -z "$APACHE_SERVER_ALIAS" ]; then
     LogMessage "ERROR: Apache(httpd) host FQDN is empty"
     return 1
  fi
  $SED -e "s/APACHE_SERVER_HOSTNAME/$APACHE_SERVER_ALIAS/g" $MANAGE_ROLE_JS > /tmp/manageRole.js
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: failed to update $MANAGE_ROLE_JS"
     return 1
  fi
  \cp /tmp/manageRole.js ${MANAGE_ROLE_JS}

  ${RM} -f /tmp/temp_openidm_startup.sh /tmp/isValidSync.js /tmp/updateLdap.js /tmp/provisioner.openicf-ldap.json /tmp/scheduler.json /tmp/sync.json /tmp/updateRole.js /tmp/createRole.js /tmp/system.properties /tmp/repo.jdbc.json /tmp/manageRole.js /tmp/managePassword.js

  LogMessage "UpdateConfigFiles completed successfully..."
  return 0
}

#######################################################################################
# Function:  SetOpenIDMKeyStorePassword
# Description: Change OpenIDM keystore password to openidm admin password in SED
#              Replace the default symmetric key in the keystore
# Parameters:  nothing
# Returns:    0  success
#             1  fail
#######################################################################################
#
SetOpenIDMKeyStorePassword()
{
  OPENIDM_SYM_KEY_DEFAULT="openidm-sym-default"
  OPENIDM_TMP_SYM_KEYSTORE=/ericsson/tor/data/idenmgmt/openidm-sym-keystore.jceks
  OPENIDM_TMP_SYM_KEYSTORE_PWD=$OPENIDM_PWD

  #change the default openidm's keystore password to openidm admin's password
  $JAVA_KEYTOOL -storepasswd -keystore $KEYSTORE_NAME -storetype $STORE_TYPE -storepass $KEYSTORE_PWD -new $OPENIDM_PWD
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to change the default openidm's keystore password to openidm admin's password"
    return 1
  fi

  #change the default openidm's truststore password to openidm admin's password
  $JAVA_KEYTOOL -storepasswd -keystore $TRUSTSTORE_NAME -storepass $KEYSTORE_PWD -new $OPENIDM_PWD
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to change the default openidm's truststore password to openidm admin's password"
    return 1
  fi

  KEYSTORE_PWD=$OPENIDM_PWD

  #delete the default openidm symmetric key
  $JAVA_KEYTOOL -delete -alias $OPENIDM_SYM_KEY_DEFAULT -keystore $KEYSTORE_NAME -storetype $STORE_TYPE -storepass $KEYSTORE_PWD
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to delete the default openidm symmetric key"
    return 1
  fi

  if [ -r "${OPENIDM_TMP_SYM_KEYSTORE}" ]; then
    #import the openidm symmetric key from openidm-sym-keystore
    $JAVA_KEYTOOL -importkeystore -srckeystore $OPENIDM_TMP_SYM_KEYSTORE -srcstoretype $STORE_TYPE -srcstorepass $OPENIDM_TMP_SYM_KEYSTORE_PWD  -destkeystore $KEYSTORE_NAME -deststoretype $STORE_TYPE -deststorepass $KEYSTORE_PWD -srcalias $OPENIDM_SYM_KEY_DEFAULT -destalias $OPENIDM_SYM_KEY_DEFAULT -srckeypass $OPENIDM_TMP_SYM_KEYSTORE_PWD -destkeypass $KEYSTORE_PWD
    if [ $? != 0 ] ; then
      LogMessage "ERROR: Failed to import the openidm symmetric key from openidm-sym-keystore"
      return 1
    fi
  else
    LogMessage "ERROR: ${OPENIDM_TMP_SYM_KEYSTORE} not found"
    return 1
  fi

  #Obfuscate openIDM keystore password
  OBF_KEYSTORE_PASSWORD=`$JAVA -jar ${OpenIDM_HOME}/bundle/openidm-crypto-2.1.0.jar ${KEYSTORE_PWD} 2>&1 | grep "OBF:"`
  if [ -z "${OBF_KEYSTORE_PASSWORD}" ]; then
    LogMessage "ERROR: Failed to obfuscate openIDM keystore password"
    return 1
  fi

  #Update boot.properties with the obfuscated keystore password
  $SED -e "s/openidm.keystore.password=changeit/openidm.keystore.password=${OBF_KEYSTORE_PASSWORD}/g" ${OPENIDM_BOOT_PROPERTIES_FILE} > /tmp/boot.properties
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: Failed to update ${OPENIDM_BOOT_PROPERTIES_FILE} with the obfuscated keystore password"
     return 1
  fi
  \cp /tmp/boot.properties ${OPENIDM_BOOT_PROPERTIES_FILE}
  ${RM} -f /tmp/boot.properties

  LogMessage "SetOpenIDMKeyStorePassword completed successfully..."
  return 0;
}

#####################################################################################
# Function:  ConfigOpenidmCertificates
# Description: Creates certificates for openidm, sign them with the rootCA cert and
#              imports all of them into openidm keystore and truststore
# Parameters:  nothing
# Returns:    0  success
#             1  fail
#####################################################################################
#
ConfigOpenidmCertificates()
{
  LogMessage "ConfigOpenidmCertificates invoked, processing request..."

  KEYSTORE_PWD=$OPENIDM_PWD

  openidm_alias1=${LOCAL_HOSTNAME}
  openidm_alias2=`${GETENT} hosts httpd | ${AWK} '{print $2}'`
  rc=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get the second apache(httpd) host FQDN from getent, return code: $rc"
    return 1
  fi
  openidm_alias3=`${GETENT} hosts httpd | ${AWK} '{print $4}'`
  rc=$?
  if [ $? -ne 0 ]; then
    LogMessage "ERROR: failed to get the fourth apache(httpd) host FQDN from getent, return code: $rc"
    return 1
  fi

  if [ -z "${openidm_alias1}" -o -z "${openidm_alias2}" -o -z "${openidm_alias3}" ]; then
    LogMessage "ERROR: One or more openidm aliases is empty"
    return 1
  fi

  $SED -e "s/OPENIDMHOST1/${openidm_alias1}/g" -e "s/OPENIDMHOST2/${openidm_alias2}/g" -e "s/OPENIDMHOST3/${openidm_alias3}/g" ${OPENIDM_SSL_EXT_FILE} > /tmp/openidm_ssl_ext
  if [ $? -ne 0 ]; then
     LogMessage "ERROR: Failed to update ${OPENIDM_SSL_EXT_FILE}"
     return 1
  fi
  \cp /tmp/openidm_ssl_ext ${OPENIDM_SSL_EXT_FILE}
  ${RM} -f /tmp/openidm_ssl_ext

  #import the rootCA into openidm's keystore
  $JAVA_KEYTOOL -import -no-prompt -trustcacerts -alias rootCA -keystore $KEYSTORE_NAME -storetype $STORE_TYPE -storepass $KEYSTORE_PWD -file $ROOTCA_FILE
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import the Root CA into OpenIDM's keystore"
    return 1
  fi

  #delete the truststore to cleanup all default trusted certs
  \rm -rf $TRUSTSTORE_NAME

  #import the rootCA into openidm's truststore
  $JAVA_KEYTOOL -import -trustcacerts  -no-prompt -alias rootCA -keystore $TRUSTSTORE_NAME -storepass $KEYSTORE_PWD -file $ROOTCA_FILE
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import the Root CA into OpenIDM's truststore"
    return 1
  fi
  #delete the self-signed certificates from openidm keystore
  $JAVA_KEYTOOL -delete -alias openidm-local-openidm-forgerock-org -keystore $KEYSTORE_NAME -storepass $KEYSTORE_PWD -storetype $STORE_TYPE
  if [ $? != 0 ] ; then
     LogMessage "ERROR: Failed to delete Openidm's self-signed certificate: openidm-local-openidm-forgerock-org from the keystore"
     return 1
   fi
   
  $JAVA_KEYTOOL -delete -alias openidm-localhost -keystore $KEYSTORE_NAME -storepass $KEYSTORE_PWD -storetype $STORE_TYPE
  if [ $? != 0 ] ; then
     LogMessage "ERROR: Failed to delete Openidm's self-signed certificate: openidm-localhost from the keystore"
     return 1
   fi
   
  #Create, sign and export Openidm certificate openidm-local-openidm-forgerock-org
  $JAVA_KEYTOOL -genkey -alias openidm-local-openidm-forgerock-org -validity $KEY_VALIDITY_PERIOD -keyalg "RSA" -keysize 2048 -dname "CN=${OPENIDM_HOST}" -keystore $KEYSTORE_NAME -keypass "$KEYSTORE_PWD"  -storepass "$KEYSTORE_PWD" -storetype $STORE_TYPE
  if [ $? != 0 ] ; then
     LogMessage "ERROR: Failed to generate Openidm keypair for certificate openidm-local-openidm-forgerock-org "
     return 1
  fi

  # Create a CSR
  $JAVA_KEYTOOL -certreq -v -alias openidm-local-openidm-forgerock-org -keystore $KEYSTORE_NAME -storepass "$KEYSTORE_PWD" -storetype $STORE_TYPE -file "${IDENMGMT_DIR}/openidm/config/openidm-local-openidm-forgerock-org.csr"
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to create a CSR for Openidm's certificate openidm-local-openidm-forgerock-org"
    return 1
  fi

  # Sign the CSR using the Root CA
  $OPENSSL x509 -req -in ${IDENMGMT_DIR}/openidm/config/openidm-local-openidm-forgerock-org.csr -CA ${ROOTCA_FILE} -CAkey ${ROOTCA_KEY_FILE} -CAcreateserial -out ${IDENMGMT_DIR}/openidm/config/openidm-local-openidm-forgerock-org.pem -days $KEY_VALIDITY_PERIOD 
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to sign a CSR for Openidm's certificate openidm-local-openidm-forgerock-org"
    return 1
  fi

  #Create, sign and export Openidm certificate openidm-localhost
  $JAVA_KEYTOOL -genkey -alias openidm-localhost -validity $KEY_VALIDITY_PERIOD -keyalg "RSA" -keysize 2048 -dname "CN=${OPENIDM_HOST}" -keystore $KEYSTORE_NAME -keypass "$KEYSTORE_PWD"  -storepass "$KEYSTORE_PWD" -storetype $STORE_TYPE
  if [ $? != 0 ] ; then
     LogMessage "ERROR: Failed to generate Openidm keypair for certificate openidm-localhost"
     return 1
  fi

  # Create a CSR
  $JAVA_KEYTOOL -certreq -v -alias openidm-localhost -keystore $KEYSTORE_NAME -storepass "$KEYSTORE_PWD" -storetype $STORE_TYPE -file "${IDENMGMT_DIR}/openidm/config/openidm-localhost.csr"
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to create a CSR for Openidm's certificate openidm-localhost"
    return 1
  fi

  # Sign the CSR using the Root CA
  $OPENSSL x509 -req -in ${IDENMGMT_DIR}/openidm/config/openidm-localhost.csr -CA ${ROOTCA_FILE} -CAkey ${ROOTCA_KEY_FILE} -CAcreateserial -out ${IDENMGMT_DIR}/openidm/config/openidm-localhost.pem -days $KEY_VALIDITY_PERIOD -extensions v3_req -extfile ${OPENIDM_SSL_EXT_FILE}
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to sign a CSR for Openidm's certificate openidm-localhost"
    return 1
  fi

  #import openidm certificates into the keystore
  $JAVA_KEYTOOL -import -no-prompt -trustcacerts -alias openidm-local-openidm-forgerock-org -keystore $KEYSTORE_NAME -storepass $KEYSTORE_PWD -storetype $STORE_TYPE -file ${IDENMGMT_DIR}/openidm/config/openidm-local-openidm-forgerock-org.pem
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import Openidm's certificate  openidm-local-openidm-forgerock-org into the keystore"
    return 1
  fi

  #import openidm's certificate into openidm's trustore
  $JAVA_KEYTOOL -import -no-prompt -trustcacerts -alias openidm-local-openidm-forgerock-org -keystore $TRUSTSTORE_NAME -storepass $KEYSTORE_PWD -file ${IDENMGMT_DIR}/openidm/config/openidm-local-openidm-forgerock-org.pem
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import Openidm's certificate openidm-local-openidm-forgerock-org into the truststore"
    return 1
  fi

  $JAVA_KEYTOOL -import -no-prompt -trustcacerts -alias openidm-localhost -keystore $KEYSTORE_NAME -storepass $KEYSTORE_PWD -storetype $STORE_TYPE -file ${IDENMGMT_DIR}/openidm/config/openidm-localhost.pem
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import Openidm's certificate  openidm-localhost into the keystore"
    return 1
  fi

  #import openidm's certificate into openidm's trustore
  $JAVA_KEYTOOL -import -no-prompt -trustcacerts -alias openidm-localhost -keystore $TRUSTSTORE_NAME -storepass $KEYSTORE_PWD -file ${IDENMGMT_DIR}/openidm/config/openidm-localhost.pem
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import Openidm's certificate openidm-localhost into the truststore"
    return 1
  fi
  # remove the csr files
  rm -f ${IDENMGMT_DIR}/openidm/config/*.csr
 
  #import apache server certificate into openidm truststore
  $JAVA_KEYTOOL -import -trustcacerts  -no-prompt -alias ssoapacheserver -keystore $TRUSTSTORE_NAME -storepass $KEYSTORE_PWD -file $APACHE_SERVER_CERT_FILE
  if [ $? != 0 ] ; then
    LogMessage "ERROR: Failed to import the certificate of Apache server certificate into OpenIDM's truststore"
    return 1
  fi

  LogMessage "ConfigOpenidmCertificates completed successfully..."

  return 0
}

#################################################################################
# Start OpenIDM and wait until OpenIDM is running
# Parameters:  nothing
# Returns:    0  success
#             1  fail
################################################################################
StartOpenIDM(){

  if [ "$NODE_ID" != 1 ]; then
    LogMessage "INFO: StartOpenIDM() only required on SC-1"
    return 0
  fi

  LogMessage "INFO: Starting OpenIDM..."
  retVal=`$OpenIDM_Start`
  rc=$?
  if [ $rc -ne 0 ]; then
    LogMessage "ERROR: failed to start OpenIDM [$rc]"
    LogMessage "ERROR: failed to start OpenIDM [$retVal]"
    return 1
  fi

  OpenidmStatus=`$OpenIDM_Status`
  LogMessage "$OpenidmStatus"
  now_ts=$(date +%s)
  later_ts=$((now_ts + 60))
  until [[ "$OpenidmStatus" =~ .*running.* ]]; do
    if [ $(date +%s) -gt $later_ts ]; then
      LogMessage "ERROR: OpenIDM is not started in 60 seconds."
      return 1
    fi
    sleep 5
    OpenidmStatus=`$OpenIDM_Status`
    LogMessage "$OpenidmStatus"
  done

  sleep 30

  if [ "${NODE_ID}" == "1" ]; then
    now_ts=$(date +%s)
    later_ts=$((now_ts + 60))
    #try to connect to openidm server to test if openidm is running
    retVal=`$CURL -u ${OPENIDM_USER}:${OPENIDM_PWD} -X GET "http://localhost:${OPENIDM_PORT}/openidm/info/ping" 2>/dev/null`
    LogMessage "$retVal"
    until [[ $retVal =  '{"state":"ACTIVE_READY","shortDesc":"OpenIDM ready"}' ]]; do
      if [ $(date +%s) -gt $later_ts ]; then
        LogMessage "ERROR: OpenIDM is not started in 60 seconds."
        return 1
      fi
      sleep 5
      retVal=`$CURL -u ${OPENIDM_USER}:${OPENIDM_PWD} -X GET "http://localhost:${OPENIDM_PORT}/openidm/info/ping" 2>/dev/null`
      LogMessage "$retVal"
    done
  fi

  #checking connections
  now_ts=$(date +%s)
  later_ts=$((now_ts + 60))
  #ask ldap about non-existing user. It return status 500 if connection with ldap is broken.
  #can be changed in OpenIDM 3.0 or higher to "http://localhost:${OPENIDM_PORT}/openidm/system/?_action=test"
  LogMessage "INFO: Checking connection to ldap..."
  retVal=`$CURL -u ${OPENIDM_USER}:${OPENIDM_PWD} -X GET "http://localhost:${OPENIDM_PORT}/openidm/system/ldap/account/uid=administrator" 2>/dev/null`
  while [[ $retVal =~ \"error\"\:500 ]]; do
    if [ $(date +%s) -gt $later_ts ]; then
      LogMessage "ERROR: OpenIDM is not ready due problem with connection to ldap."
      return 1
    fi
    sleep 5
    retVal=`$CURL -u ${OPENIDM_USER}:${OPENIDM_PWD} -X GET "http://localhost:${OPENIDM_PORT}/openidm/system/ldap/account/uid=administrator" 2>/dev/null`
    LogMessage "$retVal"
  done
  #end checking connections

  LogMessage "INFO: OpenIDM started successfully"
  return 0
}

#################################################################################
# Stop OpenIDM if it is running and wait until OpenIDM is stopped
# Parameters:  nothing
# Returns:    0  success
#             1  fail
################################################################################
StopOpenIDM(){

  if [ "$NODE_ID" != 1 ]; then
    LogMessage "INFO: StopOpenIDM() only required on SC-1"
    return 0
  fi

  LogMessage "INFO: Checking OpenIDM status"
  OpenidmStatus=`$OpenIDM_Status`
  LogMessage "$OpenidmStatus"
  if [[ "$OpenidmStatus" =~ .*running.*  ]]; then
    LogMessage "INFO: Stopping OpenIDM..."
    retVal=`$OpenIDM_Stop`
    if [ $? -ne 0 ]; then
      LogMessage "ERROR: failed to stop OpenIDM [$retVal]"
      return 1
    fi

    OpenidmStatus=`$OpenIDM_Status`
    LogMessage "$OpenidmStatus"
    now_ts=$(date +%s)
    later_ts=$((now_ts + 60))
    until [[ "$OpenidmStatus" =~ .*stopped.* ]]; do
      if [ $(date +%s) -gt $later_ts ]; then
        LogMessage "ERROR: OpenIDM is not stopped in 60 seconds."
        return 1
      fi
      sleep 5
      OpenidmStatus=`$OpenIDM_Status`
      LogMessage "$OpenidmStatus"
    done
    LogMessage "INFO: OpenIDM stopped successfully"
  elif [[ "$OpenidmStatus" =~ .*stopped.* ]]; then
    LogMessage "INFO: OpenIDM is already stopped"
  else
    LogMessage "ERROR: OpenIDM is in wrong status"
    return 1
  fi

  return 0
}


#################################################################################
# Primes default security data (default security administrator and default roles)
# Parameters:  nothing
# Returns:    0  success
#             1  fail
#################################################################################
PrimeSecurityData(){
  LogMessage "INFO: PrimeSecurityData invoked, processing request..."

  if [ "$NODE_ID" != 1 ]; then
    LogMessage "INFO: Prime default security data only on SC-1"
    return 0
  fi


  ##Create default roles
  for role in $DEFAULT_ROLES; do
    LogMessage "INFO: Creating default role: [$role]..."
    curlRetVal=`$CURL --header "X-OpenIDM-Username:$OPENIDM_USER" \
          --header "X-OpenIDM-Password:$OPENIDM_PWD" \
          --request PUT \
          --data '{"roleName":"'$role'", "description":"This is the ENM '$role' Default Role"}' \
          http://localhost:$OPENIDM_PORT/openidm/managed/role/"$role" 2>/dev/null`
    LogMessage "$curlRetVal"
    ldapRetVal=`$LDAPSEARCH -Z -X -p ${COM_INF_LDAP_PORT} -D "$LDAP_ADMIN_CN" -w $DM_PWD -b "ou=roles,$COM_INF_LDAP_ROOT_SUFFIX" cn=$role | grep "cn: $role" 2>/dev/null`
    LogMessage "$ldapRetVal"
    if [[ $ldapRetVal != "cn: $role" || $curlRetVal != "{\"_id\":\"$role\",\"_rev\":\"0\"}" ]]; then
      LogMessage "ERROR: failed to create role [$role]"
      return 1
    fi
    
  done

  ##Create security administor
  LogMessage "INFO: Creating default security administrator user [$SECURIY_ADMIN_UID]..."
  curlRetVal=`$CURL --header "X-OpenIDM-Username:$OPENIDM_USER" \
        --header "X-OpenIDM-Password:$OPENIDM_PWD" \
        --request PUT \
        --data '{"userName":"'$SECURIY_ADMIN_UID'", "firstName":"'$SECURIY_ADMIN_FIRST_NAME'", "lastName":"'$SECURIY_ADMIN_LAST_NAME'", "email":"'$SECURIY_ADMIN_EMAIL'", "password":"'$SECURITY_ADMIN_PWD'", "userType":"'$SECURIY_ADMIN_UTYPE'", "status":"Enabled"}' \
        http://localhost:$OPENIDM_PORT/openidm/managed/user/"$SECURIY_ADMIN_UID" 2>/dev/null`
  LogMessage "$curlRetVal"
  ldapRetVal=`$LDAPSEARCH -Z -X -p ${COM_INF_LDAP_PORT} -D "$LDAP_ADMIN_CN" -w $DM_PWD -b "ou=people,$COM_INF_LDAP_ROOT_SUFFIX" cn=$SECURIY_ADMIN_UID | grep "cn: $SECURIY_ADMIN_UID" 2>/dev/null`
  LogMessage "$ldapRetVal"
  if [[ $ldapRetVal != "cn: $SECURIY_ADMIN_UID" || $curlRetVal != "{\"_id\":\"$SECURIY_ADMIN_UID\",\"_rev\":\"0\"}" ]]; then
    LogMessage "ERROR: failed to create security admin user [$SECURIY_ADMIN_UID]"
    return 1
  fi
  LogMessage "INFO: Assigning Super User Password policy to default security administrator user [$SECURIY_ADMIN_UID]..."
  $LDAPMODIFY -Z -X -p ${COM_INF_LDAP_PORT} -D "$LDAP_ADMIN_CN" -w $DM_PWD <<EOT
dn: uid=$SECURIY_ADMIN_UID,ou=people,$COM_INF_LDAP_ROOT_SUFFIX
changetype: modify
add: ds-pwp-password-policy-dn
ds-pwp-password-policy-dn:cn=$SUPER_USER_PASSWD_POLICY,cn=Password Policies,cn=config
EOT
  rr=${PIPESTATUS[0]}
  if [ $rr != 0 ] ; then
     LogMessage "ERROR: Failed to assign password policy to default security administrator user [$SECURIY_ADMIN_UID] and the error code from DS is [$rr]"
     return 1
  fi

  ##Assign security admin user[administrator] to SECURITY_ADMIN and ADMINISTRATOR role
  for role in $DEFAULT_ADMIN_ROLES; do
    LogMessage "INFO: Assigning $SECURIY_ADMIN_UID to default role: [$role]..."
    curlRetVal=`$CURL --insecure --header "X-OpenIDM-Username:$OPENIDM_USER" \
          --header "X-OpenIDM-Password:$OPENIDM_PWD" \
          --header "X-Usernames:$SECURIY_ADMIN_UID" \
          --request GET \
          "https://localhost:$OPENIDM_SECURE_PORT/openidm/endpoint/manageRole?action=adduser&rName=$role" 2>/dev/null`

    if [[ -n "$curlRetVal" ]]; then
      LogMessage "$curlRetVal"
    fi
    ldapRetVal=`$LDAPSEARCH -Z -X -p ${COM_INF_LDAP_PORT} -D "$LDAP_ADMIN_CN" -w $DM_PWD -b "ou=roles,$COM_INF_LDAP_ROOT_SUFFIX" cn=$role | grep "uniqueMember: uid=$SECURIY_ADMIN_UID" 2>/dev/null`
    LogMessage "$ldapRetVal"
    if [[ $ldapRetVal != "uniqueMember: uid=$SECURIY_ADMIN_UID,ou=People,$COM_INF_LDAP_ROOT_SUFFIX" ]]; then
      LogMessage "ERROR: failed to assign security admin [$SECURIY_ADMIN_UID] to role [$role]."
      return 1
    fi
  done

  return 0
}


###############################################################################
# Main Program
# Parameters: None
###############################################################################
source $COMMON_SCRIPT
if [ $? != 0 ] ; then
   echo "ERROR: Failed to source $COMMON_SCRIPT."
   exit 1
fi

SetLogFile
if [ $? != 0 ] ; then
   echo "ERROR: SetLogFile failed."
   exit 1
fi

# Create the audit log directory if it does not already exist
if [ ! -d "${AUDIT_LOG_DIR}" ]; then
  ${MKDIR} -p ${AUDIT_LOG_DIR}
  if [ $? != 0 ]; then
    LogMessage "ERROR: Failed to create ${AUDIT_LOG_DIR}"
    exit 1
  fi
fi

${CHOWN} openidm:openidm ${AUDIT_LOG_DIR}
if [ $? != 0 ]; then
  LogMessage "ERROR: Failed to set ownership on ${AUDIT_LOG_DIR}"
  exit 1
fi

# settings in global.properties
GLOBAL_PROPERTY_FILE=/ericsson/tor/data/global.properties

# we need the global.properties file
if [ ! -r "$GLOBAL_PROPERTY_FILE" ]; then
   LogMessage "ERROR: Cannot read $GLOBAL_PROPERTY_FILE"
   exit 1
fi

. $GLOBAL_PROPERTY_FILE

if [ "$COM_INF_LDAP_ROOT_SUFFIX" == ""  -o "$LDAP_ADMIN_PASSWORD" == "" -o "$LDAP_ADMIN_CN" == "" ]; then
   LogMessage "ERROR: one or more properties in $GLOBAL_PROPERTY_FILE is not defined"
   exit 1
fi

LogMessage "openidm installation started..." 

# Parse argument to determine if this is an install or an upgrade
if [ $1 -ne 1 -a $1 -ne 2 ]; then
   LogMessage "ERROR: Install type is missing or is wrong"
   exit 1
elif [ $1 -eq 1 ]; then
   LogMessage "INFO: This is an install"
   UnzipSource
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UnzipSource failed."
      exit 1
   fi
   SetOpenIDMKeyStorePassword
   if [ $? != 0 ] ; then
      LogMessage "ERROR: SetOpenIDMKeyStorePassword failed."
      exit 1
   fi
   UpdatePasswordsInMySQL
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UpdatePasswordsInMySQL failed."
      exit 1
   fi
   ConfigOpenidmCertificates
   if [ $? != 0 ] ; then
      LogMessage "ERROR: ConfigOpenidmCertificates failed."
      exit 1
   fi
   StartOpenIDM
   if [ $? -ne 0 ]; then
      LogMessage "ERROR: StartOpenIDM failed"
      exit 1
   fi
   PrimeSecurityData
   if [ $? != 0 ] ; then
      LogMessage "ERROR: PrimeSecurityData failed."
      exit 1
   fi
   StopOpenIDM
   if [ $? -ne 0 ]; then
      LogMessage "ERROR: StopOpenIDM failed"
      exit 1
   fi
  
   HardenOpenidm
   if [ $? -ne 0 ]; then
      LogMessage "ERROR: HardenOpenIDM failed"
      exit 1
   fi

   UnzipJettyPolicyAgent
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UnzipJettyPolicyAgent failed."
      exit 1
   fi
elif [ $1 -eq 2 ]; then
   LogMessage "INFO: This is an upgrade"
   # determine node id
   ID=`$CAT /etc/cluster/nodes/this/id`
   if [ -z "${ID}" ]; then
      LogMessage "ERROR: Failed to determine the node id"
      exit 1
   else
       ID=`expr $ID - 1`
   fi

   BackupOpenidm
   if [ $? -ne 0 ]; then
      LogMessage "ERROR: BackupOpenidm Failed"
      exit 1
   fi
   UnzipSource
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UnzipSource failed."
      exit 1
   fi
   SetOpenIDMKeyStorePassword
   if [ $? != 0 ] ; then
      LogMessage "ERROR: SetOpenIDMKeyStorePassword failed."
      exit 1
   fi
   UpdatePasswordsInMySQL
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UpdatePasswordsInMySQL failed."
      exit 1
   fi
   ConfigOpenidmCertificates
   if [ $? != 0 ] ; then
      LogMessage "ERROR: ConfigOpenidmCertificates failed."
      exit 1
   fi
   HardenOpenidm
   if [ $? -ne 0 ]; then
      LogMessage "ERROR: HardenOpenIDM failed"
      exit 1
   fi
   UnzipJettyPolicyAgent
   if [ $? != 0 ] ; then
      LogMessage "ERROR: UnzipJettyPolicyAgent failed."
      exit 1
   fi
fi
LogMessage "INFO: install_openidm.sh completed successfully." 
exit 0
