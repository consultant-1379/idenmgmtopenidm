var sourceObj = openidm.decrypt(source);
var targetObj = openidm.read("system/ldap/account/uid=" + sourceObj.userName + ",ou=People,BASE_DN");

var result = false;

//target object (object in OpenDJ) does not exist, need synchronization to create it
if (!targetObj) {
    result = true;
} else {
    result = result || (sourceObj.userName != targetObj.uid) || (sourceObj.userName != targetObj.cn) || (sourceObj.userType != targetObj.userType)
                    || (sourceObj.firstName != targetObj.givenName) || (sourceObj.lastName != targetObj.sn) || (sourceObj.email != targetObj.mail);
    if (sourceObj.status == "enabled") {
       result = result || (targetObj.disabled != false);
    }else if (sourceObj.status == "disabled"){
       result = result || (targetObj.disabled != true);
    }
    result = result || (sourceObj.password != sourceObj.ldapPassword);
    result = result || (sourceObj.passwordReset == "false") || (sourceObj.passwordReset == "true");
}

result;

