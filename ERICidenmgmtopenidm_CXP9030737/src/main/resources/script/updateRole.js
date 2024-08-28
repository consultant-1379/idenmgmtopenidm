var targetMemberArray = [];
if ( !(source.uniqueMember.replace(/\s/g,"") == "") ) {
   var sourceArray = source.uniqueMember.split(',');
   var obj = {};   // Used to check the uniqueness of the user name
   for (var i = 0; i < sourceArray.length; i++) {
      var uid = sourceArray[i].replace(/^\s+|\s+$/gm,'');

      // Check if the user name is unique, and transfer the uid to dn.
      if (!obj[uid]) {
         obj[uid] = {};
         var dn = 'uid=' + uid + ',ou=People,BASE_DN';
         targetMemberArray.push(dn);
      }
      else {
         // Found duplication
         throw "Error: The user name contains duplicated entry."
      }
   }
   target.uniqueMember = targetMemberArray;
}
