//this script is called when adding a new managed user

target.dn = 'uid=' + source.userName + ',ou=People,BASE_DN';

target.userPassword = openidm.decrypt(source.password);
if (source.status == "enabled") {
   target.disabled = "false";
}else if (source.status == "disabled"){
   target.disabled = "true";
}
