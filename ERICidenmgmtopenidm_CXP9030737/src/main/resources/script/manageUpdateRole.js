/* COMMON VARIABLES */

var roleBeingUpdated = newObject.roleName;
var oldMemberArray = [];
var newMemberArray = [];
var membersToAdd = [];
var membersToRemove = [];
var users = [];
var usersEndpoint = [];

/* SECURITY_ADMIN ROLE VARIABLES */

var MANAGED_USER_ENDPOINT = "managed/user/";
var SECURITY_ADMIN_ROLE_NAME = "SECURITY_ADMIN";
var OPENIDM_ADMIN_ROLE_NAME = "openidm-admin";
var ADMINISTRATOR_ROLE_NAME = "ADMINISTRATOR";
var ADMINISTRATOR_USER_NAME = "administrator";

/* FIELD_TECHNICIAN ROLE VARIABLES */

var FIELD_TECHNICIAN_ROLE_NAME = "FIELD_TECHNICIAN";
var SEC_SERVER_BASE_URL="http://SecServ-su-0:8080/idmservice/people/";
var SEC_SERVER_ATTR_SUFFIX="/posixattributes";
var SEC_SERVER_GROUP_HOME_DIREC_SUFFIX="?groupname=mm-smrsusers&homedirectory=/home/smrs"

/* COMMON SETUP */

//remove all white spaces in the value of uniqueMember
newObject.uniqueMember = newObject.uniqueMember.replace(/\s/g,"");


//make sure user administrator not being removed from role SECURITY_ADMIN and ADMINISTRATOR
if ((roleBeingUpdated.toUpperCase() == ADMINISTRATOR_ROLE_NAME) ||
    (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME)) {
  if (newObject.uniqueMember == "") {
    newObject.uniqueMember = ADMINISTRATOR_USER_NAME;
  }
  else if (newObject.uniqueMember.indexOf(ADMINISTRATOR_USER_NAME) == -1) {
    newObject.uniqueMember += "," + ADMINISTRATOR_USER_NAME;
  }
}

//find out the members to be added and the members to be deleted
oldMemberArray = splitStringToArray(oldObject.uniqueMember);
newMemberArray = splitStringToArray(newObject.uniqueMember);
membersToAdd = getMembersNotContained(newMemberArray, oldMemberArray);
membersToRemove = getMembersNotContained(oldMemberArray, newMemberArray);

// validate users (a user that does not exist is an invalid user)
for (var i = 0; i < membersToAdd.length; i++) {
  users[i] = queryForUserName(membersToAdd[i]);
  if (!users[i]) {
    throw "User " + membersToAdd[i] + " does not exist";
  }
  usersEndpoint[i] = MANAGED_USER_ENDPOINT + users[i]._id;
}


if (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME) {

  //add the members to be added to the openidm-admin role
  for (var i = 0; i < users.length; i++) {
    var updates = null;
    if (!users[i].roles) {
      if (users[i].roles == "") {
        //attribute roles is empty
        updates = [{"replace":"roles", "value":OPENIDM_ADMIN_ROLE_NAME}];
      }
      else {
        // attribute roles does not exist
        updates = [{"add":"roles", "value":OPENIDM_ADMIN_ROLE_NAME}];
      }
    }
    else {
      var oldRoles = splitStringToArray(users[i].roles);
      var newRoles = "";
      for (var j = 0; j < oldRoles.length; j++) {
        if (oldRoles[j].toLowerCase() != OPENIDM_ADMIN_ROLE_NAME) {
          newRoles += oldRoles[j] + ",";
        }
      }
      newRoles += OPENIDM_ADMIN_ROLE_NAME;
      updates = [{"replace":"roles", "value":newRoles}];
    }
    openidm.patch(usersEndpoint[i], users[i]._rev, updates);
  }

  //remove the memebers to be deleted from openidm-admin role
  for (var i = 0; i < membersToRemove.length; i++) {
    var user = queryForUserName(membersToRemove[i]);
    if (user) {
      var userEndpoint = MANAGED_USER_ENDPOINT + user._id;
      if (!user.roles) {
        continue;
      }
      var roles = splitStringToArray(user.roles);
      var newRoles = "";
      for (var j = 0; j < roles.length; j++) {
        if (roles[j].toLowerCase() != OPENIDM_ADMIN_ROLE_NAME) {
          if (newRoles == "") {
            newRoles += roles[j];
          }
          else {
            newRoles += "," + roles[j];
          }
        }
      }
      var updates = [{"replace":"roles", "value":newRoles}];
      openidm.patch(userEndpoint, user._rev, updates);
    }
  }
}

if (roleBeingUpdated.toUpperCase() == FIELD_TECHNICIAN_ROLE_NAME) {
  for (var i = 0; i < users.length; i++) {
    var URL=SEC_SERVER_BASE_URL+users[i].userName+SEC_SERVER_ATTR_SUFFIX+SEC_SERVER_GROUP_HOME_DIREC_SUFFIX;
    var secServReq={
      "_url" : URL,
      "_method" : "PUT",
      "_headers" : {"Content-Type" : "application/json;charset=UTF-8"},
      "_body" : ""
    };
    var response=openidm.action("external/rest",secServReq);
    if (response.code != "200") {
      logger.error("Add Posix Attributes for user " +users[i].userName+" failed.");
      logger.error("Error code: " + response.code +". Message: " +response.reason);
    }
    else {
      logger.info("Add Posix Attributes for user " +users[i].userName+"  successfully")
    }
  }

  for (var i = 0; i < membersToRemove.length; i++) {
    var URL = SEC_SERVER_BASE_URL+membersToRemove[i]+SEC_SERVER_ATTR_SUFFIX;
    var secServReq={
      "_url" : URL,
      "_method" : "DELETE",
      "_headers" : {"Content-Type" : "application/json;charset=UTF-8"},
      "_body" : ""
    };
    var response = openidm.action("external/rest",secServReq);
    logger.info(response.code + ": " + response.reason);
    if (response.code != "200") {
      logger.error("Remove Posix Attributes for user " +membersToRemove[i] +" failed.");
      logger.error("Error code: " +response.code + ". Message: " +response.reason);
    }
    else {
      logger.info("Remove posix attributes for user " + membersToRemove[i] +" succeed.");
    }
  }
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
    var isDuplicated = {};
    for (var i = 0; i < memberArray.length; i++) {
      memberArray[i] = memberArray[i].replace(/^\s+|\s+$/gm,'');
      if (!isDuplicated[memberArray[i]]) {
        isDuplicated[memberArray[i]] = {};
        retVal.push(memberArray[i]);
      }
      else {
        throw "Error: The user name contains duplicated entry."
      }
    }
    return retVal;
  }
  else {
    return [];
  }
}



/**
 * @brief: Build an object with each member in the array as attributes
 * @param: an array of members
 * @return: the buit object
 */
function getContainedMembers(memberArray) {
  var retval = {};
  for (var i = 0; i < memberArray.length; i++) {
    retval[memberArray[i]] = {};
  }
  return retval;
}


/**
 * @brief: Find the members that in array A but not in array B
 * @param: member array A
 * @param: member array B
 * @return: array of members in array A not in array B
 */
function getMembersNotContained(memberArrayA, memberArrayB) {
  var retval = [];
  var containedMembers = getContainedMembers(memberArrayB)
  for (var i = 0; i < memberArrayA.length; i++) {
    if (!containedMembers[memberArrayA[i]]) {
      //member[i] is not contained
      retval.push(memberArrayA[i]);
    }
  }
  return retval;
}


/**
 * @brief: Query for user obeject under the MANAGED_USER_ENDPOINT
 * @param: userName
 * @return: one and only one user object if found, otherwise, null
 */
function queryForUserName(userName) {
  var params = {"_queryId":"for-userName", "uid":userName};
  var val = openidm.query(MANAGED_USER_ENDPOINT, params);
  if (!val || !val.result || val.result.length != 1) {
    return null;
  }
  var userObj = val.result[0];
  if (!userObj || !userObj.userName || userObj.userName != userName) {
    return null;
  }
  return userObj;
}
