var uniqueMemberArray = source.isMemberOf;
var memberList = [];
for (var i = 0; i < uniqueMemberArray.length; i++) {
        var memberdnsplit = splitStringToArray(uniqueMemberArray[i]);
        var membercn = memberdnsplit[0];
        var member = membercn.substr(3);
        if (member != "mm-smrsusers") {
           memberList.push(member);
        }
}

target.isMemberOf = memberList.join();
        
/**
 * @brief: Split string into an array. String is separated by comma
 * @param: a string contains several members separated by comma
 * @return: an array of members
 */
function splitStringToArray(memberString) {
  if (memberString.replace(/\s/g,"") != "") {
    var retVal = [];
    var memberArray = memberString.split(',');
    for (var i = 0; i < memberArray.length; i++) {
      memberArray[i] = memberArray[i].replace(/^\s+|\s+$/gm,'');
      retVal.push(memberArray[i]);
    }
    return retVal;
  }
  else {
    return [];
  }
}

