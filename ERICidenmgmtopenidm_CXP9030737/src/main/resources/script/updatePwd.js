var sourceObj = openidm.decrypt(source);

if (target.userPassword != undefined) {
  delete target.userPassword;
}

if (target.pwdReset != undefined) {
  delete target.pwdReset;
}

if (sourceObj.password != sourceObj.ldapPassword) {
  target.userPassword = sourceObj.password;
}

if (sourceObj.passwordReset == "false") {
  target.pwdReset = false;
} else if (sourceObj.passwordReset == "true") {
  target.pwdReset = true;
}

if (source.status == "enabled") {
   target.disabled = "false";
}else if (source.status == "disabled"){
   target.disabled = "true";
}

