#/bin/ksh

################################################################################
# Copyright (c) 2013 Ericsson, Inc. All Rights Reserved.
# This script uninstalls the OpenIDM directory server
# 
# 
###############################################################################

# Temporary directory definitions
TMP_DIR=/tmp
DATENOW=$(/bin/date +"%Y-%m-%d-%H:%M")
LOG_DIR="/var/log/openidm"
LOG_FILE="$LOG_DIR/uninstall-openidm-${DATENOW}.log"

# OpenIDM deployment paths
IDENMGMT_DIR=/opt/ericsson/com.ericsson.oss.security/idenmgmt
IDENMGMT_DIR_openidm=/opt/ericsson/com.ericsson.oss.security/idenmgmt/openidm
OpenIDM_HOME=/opt/openidm
OpenIDM_CONFIG_DIR=$openidm_HOME/config
OpenIDM_BIN_DIR=$openidm_HOME/bin
COMMON_SCRIPT="$IDENMGMT_DIR_openidm/bin/common.sh"

###############################################################################
# Main Program
# Parameters: None
###############################################################################
source $COMMON_SCRIPT
if [ $? -ne 0 ]; then
   echo "ERROR: Failed to source $COMMON_SCRIPT"
   exit 1
fi


SetLogFile
if [ $? -ne 0 ]; then
   echo "ERROR: SetLogFile failed"
   exit 1
fi

LogMessage "OpenIDM uninstallation logging started..." 


/etc/init.d/opendim stop
if [ $? -ne  0 ] ; then
   LogMessage "WARNING: Unable to stop openidm using /etc/init.d/opendim stop" 
   for i in `/bin/ps -ef |/bin/grep openidm |/bin/grep -v grep |/bin/awk '{print $2}'`;
   do
     /bin/kill -9 $i;
   done
fi
LogMessage "uninstall_openidm.sh completed successfully." 
exit 0
