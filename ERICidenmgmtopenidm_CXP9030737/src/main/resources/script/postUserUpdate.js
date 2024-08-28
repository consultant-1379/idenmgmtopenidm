var syncObj = openidm.decrypt(source);

if (syncObj.password != syncObj.ldapPassword) {
  var update = [{"replace":"ldapPassword", "value":syncObj.password},{"replace":"passwordReset", "value":"default"}];
  openidm.patch("managed/user/" + syncObj._id, syncObj._rev, update);
} else if (syncObj.passwordReset != "default") {
  var update = [{"replace":"passwordReset", "value":"default"}];
  openidm.patch("managed/user/" + syncObj._id, syncObj._rev, update);
}

