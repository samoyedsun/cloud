console.log("document.domain:", document.domain)

var uid = 10000000
var token = "76491a8d530c11f397789e45bb7c5237a67f185e"

function user_local_login(){
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if ( xhr.readyState == 4 ){
            if ( ( xhr.status >= 200 && xhr.status < 300 ) || xhr.status == 304 ) {
                document.getElementById("field_recv").value =  xhr.responseText
            } else {
                alert("失败＝")
            }
        }
    }
    xhr.open('POST', "http://" + document.domain + ":8203" + "/user/local_login", true );
    var data = JSON.stringify({
        uid : uid,
        token : token
    });
    xhr.send(data);
}

function user_info(){
    var socket = new Socket();
    socket.connect("ws://" + document.domain + ":9948" + "/ws");
    socket.on("onopen", function () {
        socket.request("user_auth", {
            uid : uid,
            token : token,
            platform : "website"
        }, function (args) {
            console.log(args)
            socket.request("user_info", {
                uid : uid
            }, function (args) {
                document.getElementById("field_recv").value = JSON.stringify(args)
                socket.close()
            });
        });
    });
}