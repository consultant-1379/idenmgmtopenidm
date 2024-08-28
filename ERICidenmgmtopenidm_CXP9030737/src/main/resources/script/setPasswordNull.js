if (request.value.before !== undefined && request.value.before !== null) {
    if (request.value.before.userPassword !== undefined && request.value.before.userPassword !== null) {
        request.value.before.userPassword = null;
    }
}
if (request.value.after !== undefined && request.value.after !== null) {
    if (request.value.after.userPassword !== undefined && request.value.after.userPassword !== null) {
        request.value.after.userPassword = null;
    }
}

if (request.parent && request.parent.parent) {
   if (request.parent.parent.value !== undefined && request.parent.parent.value !== null) {
       if (request.parent.parent.value.userPassword !== undefined && request.parent.parent.value.userPassword !== null) {
           request.parent.parent.value.userPassword = null;
       }
   }
}
