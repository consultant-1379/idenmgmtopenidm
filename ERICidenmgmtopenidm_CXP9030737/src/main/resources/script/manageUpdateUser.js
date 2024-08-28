//this script is called when updating an existing user to ensure
// that the new status is stored in lowercase

logger.info ("Executing updateUser");

var OPENIDM_ADMIN_ROLE = "openidm-admin";
var OPENIDM_AUTHORIZED_ROLE = "openidm-authorized"
var DEFAULT_SECURITY_ADMIN = "administrator";

var updatedStatus = newObject.status;

newObject.status = updatedStatus.toLowerCase();

//default security admin must have openidm-admin role
if (newObject.userName == DEFAULT_SECURITY_ADMIN) {
  if (!newObject.roles) {
    newObject.roles = OPENIDM_ADMIN_ROLE;
  } else if (newObject.roles.indexOf(OPENIDM_ADMIN_ROLE) == -1) {
    newObject.roles += "," + OPENIDM_ADMIN_ROLE;
  }
}

//all users must have openidm-authorized role
if (!newObject.roles) {
  newObject.roles = OPENIDM_AUTHORIZED_ROLE;
} else if (newObject.roles.indexOf(OPENIDM_AUTHORIZED_ROLE) == -1) {
  newObject.roles += "," + OPENIDM_AUTHORIZED_ROLE;
}

//if admin use PUT method to update user object without ldapPassword
if (!newObject.ldapPassword) {
  newObject.ldapPassword = oldObject.ldapPassword;
}
if (!newObject.passwordReset) {
  newObject.passwordReset = oldObject.passwordReset;
}
//if OpenDJ update ldapPassword
if (newObject.ldapPassword != oldObject.ldapPassword) {
  newObject.password = newObject.ldapPassword;
}

