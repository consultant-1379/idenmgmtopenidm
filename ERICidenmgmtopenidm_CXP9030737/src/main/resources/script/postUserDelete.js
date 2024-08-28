// Trigger a reconciliation to sync user isMemberOf attribute back to openIDM
openidm.action('sync', {"_action":"recon","mapping":"systemLdapRoles_managedRole"});

