var host = "127.0.0.1"
var node_host = host + ":8201"

var test_cjson1 = function ()
{
    var HTTP_URL = "http://" + node_host + "/test_cjson1";
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if ( xhr.readyState == 4 ) {
            if ( ( xhr.status >= 200 && xhr.status < 300 ) || xhr.status == 304 ) {
                var tmp = JSON.parse(xhr.responseText)
                var response_text_tmp = xhr.responseText
                if (tmp instanceof Array)
                    response_text_tmp = "是数组：\n" + response_text_tmp
                else
                    response_text_tmp = "不是数组：\n" + response_text_tmp
                document.getElementById("field").value = response_text_tmp
            } else {
                alert("失败！")
            }
        }
    };
    xhr.open('POST', HTTP_URL, true );
    var data = JSON.stringify({type : 1});
    xhr.send(data);
}

var test_cjson2 = function ()
{
    var HTTP_URL = "http://" + node_host + "/test_cjson2";
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if ( xhr.readyState == 4 ) {
            if ( ( xhr.status >= 200 && xhr.status < 300 ) || xhr.status == 304 ) {
                var tmp = JSON.parse(xhr.responseText)
                var response_text_tmp = xhr.responseText
                if (tmp instanceof Array)
                    response_text_tmp = "是数组：\n" + response_text_tmp
                else
                    response_text_tmp = "不是数组：\n" + response_text_tmp
                document.getElementById("field").value = response_text_tmp
            } else {
                alert("失败！")
            }
        }
    };
    xhr.open('POST', HTTP_URL, true );
    var data = JSON.stringify({type : 2});
    xhr.send(data);
}
