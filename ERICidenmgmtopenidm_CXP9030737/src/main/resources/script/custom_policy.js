var statusPolicy = {
    "policyId" :"validStatus",
    "clientValidation":"true",
    "policyExec": "valid_status",
    "policyRequirements": ["INVALID_STATUS"]
};

var atLeastXSmallsPolicy = {
    "policyId" : "at-least-X-smalls",
    "policyExec" : "atLeastXSmallLetters",
    "clientValidation": true,
    "validateOnlyIfPresent": true,
   "policyRequirements" : ["AT_LEAST_X_SMALL_LETTERS"]
};

var reAuthPolicy = {
    "policyId" : "re-auth-policy-agent",
    "policyExec" : "reauthPolicyAgent",
    "validateOnlyIfPresent": true,
    "policyRequirements" : ["REAUTH_REQUIRED"]
};

var mixedCaseUsernameUniquePolicy = {
	"policyId" : "unique-mixed-case-username",
    "policyExec" : "uniqueMixedCaseUsername",  
    "policyRequirements" : ["UNIQUE"]	
};

var cannotContainUniqueMemberPolicy = {
    "policyId" : "cannot-contain-uniqueMember",
    "policyExec" : "cannotContainUniqueMember",
    "clientValidation": true,
    "validateOnlyIfPresent": true,
    "policyRequirements" : ["CANNOT_CONTAIN_UNIQUEMEMBER"]
};

var nonSelfDisablePolicy = {
    "policyId" : "non-self-disable",
    "policyExec" : "nonSelfDisable",
    "validateOnlyIfPresent": true,
    "policyRequirements" : ["NON_SELF_DISABLE"]
};

addPolicy(statusPolicy);
addPolicy(atLeastXSmallsPolicy);
addPolicy(reAuthPolicy);
addPolicy(mixedCaseUsernameUniquePolicy);
addPolicy(cannotContainUniqueMemberPolicy);
addPolicy(nonSelfDisablePolicy);

function cannotContainUniqueMember(fullObject, value, params, propName,roleName){
    var currentObject = openidm.read(request.id);
    if (request.parent != null && request.parent.parent !=null){
        if(request.parent.parent.path !=null && request.parent.parent.path.match(/\/managed\/role/)){
           if (currentObject.uniqueMember != fullObject.uniqueMember){
             //someone tries to update uniqueMember using ../managed/openidm/role
              return [ { "policyRequirement" : "CANNOT_CONTAIN_UNIQUEMEMBER" } ];
           }
           return [];
        }
        return [];
    }
    return [];
}

function valid_status(fullObject, value, params, propName) {
    if ((value) && (value.toLowerCase() !== 'enabled') && (value.toLowerCase() !=='disabled')) {
        return [ { "policyRequirement" : "INVALID_STATUS"  } ];
    }
    return [];
}

function atLeastXSmallLetters(fullObject, value, params, property) {
    var reg = /[(a-z)]/g;
    if (typeof(value) !== "string" || !value.length || value.match(reg) === null || value.match(reg).length < params.numCaps) {
        return [ { "policyRequirement" : "AT_LEAST_X_SMALL_LETTERS", "params" : {"numCaps": params.numCaps} } ];
    } else {
        return [];
    }
}

function reauthPolicyAgent(fullObject, value, params, propName) {
    if (checkExceptRoles(params.exceptRoles)) {
        return [];
    }
   
    var isHttp = request._isDirectHttp;
    if (isHttp == "true" || isHttp == true) {
        if (!request.id) {
            return [ { "policyRequirement" : "REAUTH_REQUIRED" } ];
        }

        var parent = request.parent;
        var headers = parent.parent.headers;
        var reAuthPassword = headers["X-OpenIDM-Reauth-Password"];
        if (!reAuthPassword) {
            return [ { "policyRequirement" : "REAUTH_REQUIRED" } ];
        }

        var currentObject = openidm.read(request.id);
        currentObject["password"] = openidm.decrypt(currentObject["password"]);
        if (currentObject["password"] === reAuthPassword) {
            // this means the value is the same
            return [];
        } else {
            return [ { "policyRequirement" : "REAUTH_REQUIRED" } ];
        }
    }

    return [];
}

function uniqueMixedCaseUsername (fullObject, username, params) {
    var queryParams = {
            "_queryId": "get-by-username",
            "username": username
            },
        existing,requestId,requestBaseArray;
    
    if (username && username.length)
    {
        requestBaseArray = request.id.split("/");
        if (requestBaseArray.length === 3) {
            requestId = requestBaseArray.pop();
        }
        existing = openidm.query(requestBaseArray.join("/"),  queryParams);

        if (existing.result.length != 0 && (!requestId || (existing.result[0]["_id"] != requestId))) {
            return [{"policyRequirement": "UNIQUE"}];
        }
    }
    return [];
}

function nonSelfDisable(fullObject, value, params, propName) {
    if ((value) && (value.toLowerCase() =='disabled')) {
        if (request && request.parent && request.parent.parent &&
            request.parent.parent.security && request.parent.parent.security.userid &&
            request.parent.parent.security.userid.id && fullObject && fullObject._id) {
            var uid = request.parent.parent.security.userid.id;
            var targetUid = fullObject._id;
            if (uid == targetUid) {
                return [{"policyRequirement" : "NON_SELF_DISABLE"}];
            }
        }
    }
    return [];

}

