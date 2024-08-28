//this script is called when creating a new managed user

logger.info ("Executing createUser");

var OPENIDM_AUTHORIZED_ROLE = "openidm-authorized"

var enteredStatus = object.status;

object.status = enteredStatus.toLowerCase();

object.roles = OPENIDM_AUTHORIZED_ROLE;

object.ldapPassword = object.password;

object.passwordReset = "default";

