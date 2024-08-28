var retObj;
handleRequest : {
if (!request || !request.parent || !request.parent.headers || !request.parent.method) {
  throw {"openidmCode" : 400, "message" : "Malformed or missing entity body"};
}

var method = request.parent.method;
if ((method != "GET") && (method != "POST")) {
  logger.error("ManagePassword: method {} is not supported", method);
  throw {"openidmCode" : 405, "message" : "Method not supported"};
}

var headers = request.parent.headers;
if (!headers["X-OpenIDM-Username"]) {
  logger.error("ManagePassword: user name is missing");
  throw {"openidmCode" : 401, "message" : "Missing user name"};
}
if (!headers["X-OpenIDM-Reauth-Password"]) {
  logger.error("ManagePassword: reauth password is missing");
  throw {"openidmCode" : 401, "message" : "Missing credentials"};
}
var userName = headers["X-OpenIDM-Username"];
var oldPassword = headers["X-OpenIDM-Reauth-Password"];

//query the user in OpenIDM
var userObj = queryForUserName(userName);
if (userObj == null) {
  logger.error("ManagePassword: Invalid user name or credentials");
  throw {"openidmCode" : 401, "message" : "Invalid user name or credentials 1"};
}

//authenticate user in OpenDJ
var opendjResponse;
var opendjReq={
  "_url" : "https://" + userObj.userName + ":" + oldPassword + "@OPENDJ_REST_HOST_PORT/users/" + userObj.userName,
  "_method" : "GET",
  "_headers" : {"Content-Type" : "application/json"},
  "_body" : ""
};
try {
  opendjResponse = openidm.action("external/rest",opendjReq);
} catch (exception) {
  logger.error("ManagePassword: Invalid user name or credentials");
  throw {"openidmCode" : 401, "message" : "Invalid user name or credentials 2"};
}
if (!opendjResponse || !opendjResponse.userName) {
  logger.error("ManagePassword: Invalid user name or credentials");
  throw {"openidmCode" : 401, "message" : "Invalid user name or credentials 3"};
}

//only return the entire password policy if method is GET
if (method == "GET") {
  retObj = getPolicyUsingPolicyName("password");
  break handleRequest;
}

//for method post
if (!headers["X-OpenIDM-New-Password"]) {
  logger.error("ManagePassword: new password is missing");
  throw {"openidmCode" : 400, "message" : "Missing new password"};
}
var newPassword = headers["X-OpenIDM-New-Password"];

//validate the new password against openidm password policy
var actionParams = {
  "userName"  : userObj.userName,
  "firstName" : userObj.firstName,
  "lastName"  : userObj.lastName,
  "password"  : newPassword
}
var validationResult = openidm.action("policy/managed/user/" + userObj.userName, {"_action":"validateProperty"}, actionParams);
if (validationResult.result == false) {
  logger.error("ManagePassword: password policy validation failed");
  throw {"openidmCode" : 403, "message" : "Failed policy validation", "detail" : validationResult};
}

//change password in OpenIDM
if (oldPassword == newPassword) {
  logger.error("ManagePassword: The new password cannot be the same as the current password");
  throw {"openidmCode" : 403, "message" : "The new password cannot be the same as the current password"};
}
retObj = openidm.patch("managed/user/"+userObj._id, userObj._rev, [{"replace":"password", "value":newPassword}]);
retObj = openidm.patch("managed/user/"+userObj._id, retObj._rev, [{"replace":"passwordReset", "value":"false"}]);

}// end of label: handleRequest

retObj;



/**
 * @brief: Query for user obeject under the MANAGED_USER_ENDPOINT
 * @param: userName
 * @return: one and only one user object if found, otherwise, null
 */
function queryForUserName(userName) {
  var params = {"_queryId":"for-userName", "uid":userName};
  var val = openidm.query("managed/user/", params);
  if (!val || !val.result || val.result.length != 1) {
    return null;
  }
  var userObj = val.result[0];
  if (!userObj || !userObj.userName) {
    return null;
  }
  return userObj;
}

/**
 * @brief: Return the policyIds and params for policy related to a certain property
 * @param: propertyName, string, the name of the property
 * @return: An array of policy objects of the property
 */
function getPolicyUsingPolicyName (propertyName) {
  var resource = openidm.read("policy/managed/user/" + propertyName);
  var resourceProperties = resource.properties;
  var policyArray = new Array();
  for (var i = 0; i < resourceProperties.length; i++) {
    if (resourceProperties[i].name == propertyName) {
      var resourcePolicies = resourceProperties[i].policies;
      for (var j = 0; j < resourcePolicies.length; j++) {
        var policy = {};
        policy.policyId = resourcePolicies[j].policyId;
        if (resourcePolicies[j].params) {
          policy.params = resourcePolicies[j].params;
        }
        policyArray.push(policy);
      }
    }
  }
  return policyArray;
}

