var retObj;
handleRequest : {
if (!request || !request.parent || !request.parent.method) {
  throw {"openidmCode" : 400, "message" : "Malformed or missing entity body"};
}
if (!request.params || !request.params.state || !request.value) {
  throw {"openidmCode" : 400, "message" : "Malformed or missing entity body"};
}

var method = request.parent.method;
if (method != "POST") {
  logger.error("passwordReset: method {} is not supported", method);
  throw {"openidmCode" : 405, "message" : "Method not supported"};
}

var state = request.params.state.toLowerCase();
if ((state != "true") && ((state != "false"))) {
  logger.error("passwordReset: password reset state {} is not valid", state);
  throw {"openidmCode" : 403, "message" : "Password reset state is not valid"};
}

//validate the users in OpenIDM
var userObjs = [];
var names = [];
var userNames= request.value;
for (var i = 0; i < userNames.length; i++) {
  var user = queryForUserName(userNames[i]);
  if (user == null) {
    logger.error("passwordReset: user {} is not found", userNames[i]);
    throw {"openidmCode" : 404, "message" : "User " + userNames[i] + " not found"};
  }
  names.push(userNames[i]);
  userObjs.push(user);
}

var retObj = [];
for (var i = 0; i < userObjs.length; i++) {
  try {
    retObj.push(openidm.patch("managed/user/"+userObjs[i]._id, userObjs[i]._rev, [{"replace":"passwordReset", "value":state}]));
  } catch (exception) {
    logger.error("passwordReset exception: {}", exception);
    throw {"openidmCode" : 500, "message" : "Failed to reset password for user" + userNames[i], "detail":{"processedUsers": names.slice(0,i), "remainingUsers": names.slice(i,names.length)}};
  }
}

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
  if (!userObj || !userObj.userName || userObj.userName != userName) {
    return null;
  }
  return userObj;
}


