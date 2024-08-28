/* Constants */
var ADMINISTRATOR_USER_NAME = "administrator";
var FIELD_TECHNICIAN_ROLE_NAME = "FIELD_TECHNICIAN";

/* Common variables */
var userToDelete = object;

/* Deleting administrator is not allowed */
if (userToDelete.userName.toLowerCase() == ADMINISTRATOR_USER_NAME) {
  throw "Deleting administrator is not allowed."
}

/**
 * @brief: Split string into an array. String is separated by comma
 * @param: a string contains several members separated by comma
 * @return: an array of members
*/
function splitStringToArray(memberString) {
  if (memberString.replace(/\s/g,"") != "") {
    var retVal = [];
    var memberArray = memberString.split(',');
    for (var i = 0; i < memberArray.length; i++) {
      memberArray[i] = memberArray[i].replace(/^\s+|\s+$/gm,'');
      retVal.push(memberArray[i]);
    }
    return retVal;
  } else {
    return [];
  }
}

/* Invalidating user sessions */
var si = Packages.com.ericsson.oss.security.idenmgmt.session.SessionInvalidation.getInstance();
si.invalidateSessions(userToDelete.userName);
