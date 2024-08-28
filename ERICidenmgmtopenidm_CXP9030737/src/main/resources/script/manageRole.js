/* COMMON VARIABLES */

var MANAGED_USER_ENDPOINT = "managed/user/";
var MANAGED_ROLE_ENDPOINT = "managed/role/";
var SECURITY_ADMIN_ROLE_NAME = "SECURITY_ADMIN";
var OPENIDM_ADMIN_ROLE_NAME = "openidm-admin";
var ADMINISTRATOR_ROLE_NAME = "ADMINISTRATOR";
var ADMINISTRATOR_USER_NAME = "administrator";
var FIELD_TECHNICIAN_ROLE_NAME = "FIELD_TECHNICIAN";
var SEC_SERVER_BASE_URL="https://APACHE_SERVER_HOSTNAME/idmservice/people/";
var SEC_SERVER_ATTR_SUFFIX="/posixattributes";
var SEC_SERVER_GROUP_HOME_DIREC_SUFFIX="?groupname=mm-smrsusers&homedirectory=/home/smrs"

var existingUsersArray = [];
var newUsersArray = [];    
var existingUsers;
var newUsers;

var headers = request.parent.headers;
var auth_cookie = headers["Cookie"];
var users = headers["X-Usernames"];
if (!users || users == "") {
    throw "Failed to get the username (s) to be updated from the request headers";
}

var roleBeingUpdated = request.params.rName;
var usersArray = splitStringToArray(users)

//Validate the users to be updated
for (var n=0; n < usersArray.length; n++){
   var user = queryForUserName(usersArray[n]);
   if (user == null) {
     throw {"openidmCode" : 403, "message" : "User " + usersArray[n] + " does not exist"};
   }
}
//Validate the role to be updated 
var role = queryForRoleName(roleBeingUpdated);
if (role ==null) {
   throw {"openidmCode" : 403, "message" : "Role " + roleBeingUpdated + " does not exist"};
}

if (request.method == "query" && request.params.action == "adduser") {
   returnObject = addEntry();
} else if (request.method == "query" && request.params.action == "deleteuser") {
    returnObject = deleteEntry();
} else if (request.method == "query") {
    throw "Unsupported action: " + request.params.action;
} else {
    throw "Unsupported method: " + method;
}


/**
 * @brief: adds a new a user as a memberOf a role
 * @param: none
 * @return: the modified role object
 */
function addEntry() {
    logger.info ("Adding user(s) " +users+" to role "+roleBeingUpdated);
    existingUsers = role.uniqueMember;
    if (existingUsers == "") {
       newUsers = users;
    }else {
       newUsers = existingUsers+","+ users;
    }
    newUsersArray = splitStringToArray(users);
    existingUsersArray = splitStringToArray(existingUsers);
    for (var m = 0; m < newUsersArray.length; m++){
       if (existingUsersArray.indexOf(newUsersArray[m])>-1){
           throw {"openidmCode" : 412, "message" : "User "+newUsersArray[m]+" is already assigned to role "+ roleBeingUpdated};
       }
    }

    // We need a special handling for the field technician role
    if (roleBeingUpdated.toUpperCase() == FIELD_TECHNICIAN_ROLE_NAME) {
       if (!auth_cookie || auth_cookie == "") {
          logger.error ("Failed to get the authentication cookie from the request headers");
          throw {"openidmCode" : 401, "message" : "Failed to get the authentication cookie from the request headers"};
       }

       for (var i = 0; i < newUsersArray.length; i++) {
          var URL=SEC_SERVER_BASE_URL+newUsersArray[i]+SEC_SERVER_ATTR_SUFFIX+SEC_SERVER_GROUP_HOME_DIREC_SUFFIX;
          var secServReq={
            "_url" : URL,
            "_method" : "PUT",
            "_headers" : {"Content-Type" : "application/json;charset=UTF-8", "Cookie" : auth_cookie},
            "_body" : ""
          };
          var response;
          try{
              response=openidm.action("external/rest",secServReq);
          }catch(exception){
             logger.error("manageRole: Failure when invoking ID Management Service");
             throw {"openidmCode" : 500, "message" : "Error when invoking ID Management Service"};
          }
          if (response && response.code){
            if(response.code == "200") {
              logger.info("manageRole: Adding posix attributes for user " +newUsersArray[i]+" completed successfully")
            }else{
              logger.error("manageRole: Adding posix attributes for user " +newUsersArray[i]+" failed.");
              logger.error("manageRole: Error code: " + response.code +". Message: " +response.reason);
              throw {"openidmCode" : 500, "message" : "Failed to add posix attributes for user " +newUsersArray[i] };
            }
          }else {
             logger.error("manageRole: Failure when invoking ID Management Service");
             throw {"openidmCode" : 500, "message" : "Error when invoking ID Management Service"};
          }
       }
    }//end  role =FIELD_TECHNICIAN

    if (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME) {
       //add the user to the openidm-admin role
       for (var i = 0; i < newUsersArray.length; i++) {
          var user = queryForUserName(newUsersArray[i]);
          var updates = null;
          if (!user.roles) {
             if (user.roles == "") {
                //attribute roles is empty
                updates = [{"replace":"roles", "value":OPENIDM_ADMIN_ROLE_NAME}];
             }else {
                // attribute roles does not exist
                updates = [{"add":"roles", "value":OPENIDM_ADMIN_ROLE_NAME}];
             }
          }else {
             var oldRoles = splitStringToArray(user.roles);
             var newRoles = "";
             for (var j = 0; j < oldRoles.length; j++) {
                if (oldRoles[j].toLowerCase() != OPENIDM_ADMIN_ROLE_NAME) {
                   newRoles += oldRoles[j] + ",";
                }
             }
             newRoles += OPENIDM_ADMIN_ROLE_NAME;
             updates = [{"replace":"roles", "value":newRoles}];
         }
         openidm.patch(MANAGED_USER_ENDPOINT + user._id, user._rev, updates);
      }
   }//end role = SECURITY_ADMIN_ROLE_NAME


    //Patch the managed/role object with the updated values for uniqueMember
    openidm.patch("managed/role/"+roleBeingUpdated,null,[{"replace":"uniqueMember","value":newUsers}]);

    // Update the managed/user object with the updated values for isMemberOf
    updateUserAddition(newUsersArray);

    return openidm.read("managed/role/"+roleBeingUpdated);
}

/**
 * @brief: deletes a user from a role
 * @param: none
 * @return: the modified role object
 */
function deleteEntry() {
    newUsersArray = splitStringToArray(users);
    existingUsers = role.uniqueMember;
    logger.info("The list of existing users {}", existingUsers);
    if (existingUsers == "") {
       throw {"openidmCode" : 412, "message" : "Role "+ roleBeingUpdated+" has no users to delele"};
    }else{
       existingUsersArray = splitStringToArray(existingUsers);
       for (var j = 0; j < newUsersArray.length; j++){
          if (existingUsersArray.indexOf(newUsersArray[j]) <= -1){
              throw {"openidmCode" : 412, "message" : "User "+newUsersArray[j]+" is not assigned to role "+ roleBeingUpdated};
          }
       }
    }
    logger.info ("Removing user(s) " +users+" from role "+roleBeingUpdated);
    //security admin users cannot unassign themselves from security admin role
    if (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME) {
       if (request && request.parent && request.parent.security && request.parent.security.username) {
            var requestUsername = request.parent.security.username;
            if (users.indexOf(requestUsername) > -1) {
                throw {"openidmCode" : 403, "message" : "User: "+ requestUsername + " cannot be removed from role: " +roleBeingUpdated};
            }
       }
    }
    //make sure user administrator not being removed from role SECURITY_ADMIN and ADMINISTRATOR
    if ((roleBeingUpdated.toUpperCase() == ADMINISTRATOR_ROLE_NAME) || (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME)) {
       if (users.indexOf(ADMINISTRATOR_USER_NAME) > -1 ) {
          throw {"openidmCode" : 403, "message" : "User: "+ADMINISTRATOR_USER_NAME + " cannot be removed from role: " +roleBeingUpdated}; 
       } 
    }else if (roleBeingUpdated.toUpperCase() == FIELD_TECHNICIAN_ROLE_NAME) {
       if (!auth_cookie || auth_cookie == "") {
          throw {"openidmCode" : 401, "message" : "Failed to get the authentication cookie from the request headers"};
       }

       for (var i = 0; i < newUsersArray.length; i++) {
          var URL = SEC_SERVER_BASE_URL+newUsersArray[i]+SEC_SERVER_ATTR_SUFFIX;
          var secServReq={
             "_url" : URL,
             "_method" : "DELETE",
             "_headers" : {"Content-Type" : "application/json;charset=UTF-8", "Cookie" : auth_cookie},
             "_body" : ""
          };
          var response;
          try{
              response=openidm.action("external/rest",secServReq);
          }catch(exception){
             logger.error("manageRole: Failure when invoking ID Management Service");
             throw {"openidmCode" : 500, "message" : "Error when invoking ID Management Service"};
          }
          if (response && response.code){
            if(response.code == "200") {
              logger.info("manageRole: Removing posix attributes for user " +newUsersArray[i]+" completed successfully")
            }else{
              logger.error("manageRole: Removing posix attributes for user " +newUsersArray[i]+" failed.");
              logger.error("manageRole: Error code: " + response.code +". Message: " +response.reason);
              throw {"openidmCode" : 500, "message" : "Failed to remove posix attributes for user " +newUsersArray[i] };
            }
          }else {
             logger.error("manageRole: Failure when invoking ID Management Service");
             throw {"openidmCode" : 500, "message" : "Error when invoking ID Management Service"};
          }
         
       }//end for loop
    }
    if (roleBeingUpdated.toUpperCase() == SECURITY_ADMIN_ROLE_NAME) {
       //remove the user from openidm-admin role
       for (var i = 0; i < newUsersArray.length; i++) {
          var user = queryForUserName(newUsersArray[i]);
          if (user) {
             var userEndpoint = MANAGED_USER_ENDPOINT + user._id;
             if (user.roles) {
                var roles = splitStringToArray(user.roles);
                var newRoles = "";
                for (var j = 0; j < roles.length; j++) {
                  if (roles[j].toLowerCase() != OPENIDM_ADMIN_ROLE_NAME) {
                     if (newRoles == "") {
                        newRoles += roles[j];
                     }else {
                        newRoles += "," + roles[j];
                     }
                  } 
               }
               var updates = [{"replace":"roles", "value":newRoles}];
               openidm.patch(userEndpoint, user._rev, updates);
             }
  
          }
       }
    }

    // Get the index value for each entry to be removed
    for (var k = 0; k < newUsersArray.length; k++) {
       var index = existingUsersArray.lastIndexOf(newUsersArray[k]);
       // Check the index exists in the array and remove if so
       if (index > -1) {
         existingUsersArray.splice(index,1);
         // Throw an error if not
       } else {
          throw "Invalid Entry"
       }

    }//end for loop
    //convert the array back to a comma separated string
    newUsers = existingUsersArray.join();
    // Patch the managed/role object with the updated values for uniqueMember
    openidm.patch("managed/role/"+roleBeingUpdated,null,[{"replace":"uniqueMember","value":newUsers}]);

    // Patch the managed/user object with the updated values for isMemberOf
    updateUserDeletion(newUsersArray);

    return openidm.read("managed/role/"+roleBeingUpdated);   
}

/**
 * @brief: Update each user in the new user array for the isMemberOf field.
 * @param: An array contains the users that will need to be updated.
 * @return: none
 */
function updateUserAddition(newUsersArray) {
    for (var i = 0; i < newUsersArray.length; i++) {
        var newUser = newUsersArray[i];
        var userObject = openidm.read("managed/user/" + newUser);
        var update = null;
        if (!userObject.isMemberOf) {
            if (userObject.isMemberOf == "") {
                update = [{"replace":"isMemberOf", "value":roleBeingUpdated}];
            } else {
                update = [{"add":"isMemberOf", "value":roleBeingUpdated}];
            }
        } else {
            var memberList = userObject.isMemberOf + "," + roleBeingUpdated;
            update = [{"replace":"isMemberOf", "value":memberList}];
        }
        openidm.patch("managed/user/" + newUser, null, update);
    }
}

/**
 * @brief: Update each user in the new user array for the isMemberOf field.
 * @param: An array contains the users that will need to be updated.
 * @return: none
 */
function updateUserDeletion(newUsersArray) {
    for (var i = 0; i < newUsersArray.length; i++) {
        var newUser = newUsersArray[i];
        var userObject = openidm.read("managed/user/" + newUser);
        var memberList = userObject.isMemberOf;
        memberListArray = splitStringToArray(memberList);
        var index = memberListArray.indexOf(roleBeingUpdated);
        memberListArray.splice(index, 1);
        memberList = memberListArray.join();
        openidm.patch("managed/user/" + newUser, null, [{"replace":"isMemberOf", "value":memberList}]);
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
        throw "Username " + memberArray[i] + " is duplicated";
      }
    }
    return retVal;
  }
  else {
    return [];
  }
}
/**
 * @brief: Query for user object under the MANAGED_USER_ENDPOINT
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

/**
 * @brief: Query for role object under the MANAGED_ROLE_ENDPOINT
 * @param: roleName
 * @return: one and only one role object if found, otherwise, null
 */
function queryForRoleName(roleName) {
  var params = {"_queryId":"for-roleName", "rName":roleName};
  var val = openidm.query(MANAGED_ROLE_ENDPOINT, params);
  if (!val || !val.result || val.result.length != 1) {
    return null;
  }
  var roleObj = val.result[0];
  if (!roleObj || !roleObj.roleName || roleObj.roleName != roleName) {
    return null;
  }
  return roleObj;
}
